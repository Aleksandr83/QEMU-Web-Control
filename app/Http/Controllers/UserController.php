<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Role;
use App\Models\User;
use App\Models\UserVmPermissions;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class UserController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorizeAdmin();

        $query = User::with('roles')->latest();

        $search = trim((string) $request->query('q', ''));
        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        $roleId = $request->query('role_id');
        if (!empty($roleId)) {
            $query->whereHas('roles', function ($q) use ($roleId) {
                $q->where('roles.id', $roleId);
            });
        }

        $users = $query->paginate(20)->withQueryString();
        $roles = Role::orderBy('name')->get();

        return view('users.index', compact('users', 'roles', 'search', 'roleId'));
    }

    public function create(): View
    {
        $this->authorizeAdmin();

        $roles = Role::orderBy('name')->get();

        return view('users.create', compact('roles'));
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorizeAdmin();

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'role_id' => 'required|exists:roles,id',
            'password' => 'required|string|min:4|confirmed',
            'can_create_vm' => 'nullable|boolean',
            'can_delete_vm' => 'nullable|boolean',
            'can_start_vm' => 'nullable|boolean',
            'can_stop_vm' => 'nullable|boolean',
            'can_edit_others_vm' => 'nullable|boolean',
            'can_delete_others_vm' => 'nullable|boolean',
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
        ]);
        $user->roles()->sync([$validated['role_id']]);

        $selectedRole = Role::find($validated['role_id']);
        if ($selectedRole && $selectedRole->slug !== 'administrator') {
            UserVmPermissions::create([
                'user_id' => $user->id,
                'can_create_vm' => $request->boolean('can_create_vm'),
                'can_delete_vm' => $request->boolean('can_delete_vm'),
                'can_start_vm' => $request->boolean('can_start_vm'),
                'can_stop_vm' => $request->boolean('can_stop_vm'),
                'can_edit_others_vm' => $request->boolean('can_edit_others_vm'),
                'can_delete_others_vm' => $request->boolean('can_delete_others_vm'),
            ]);
        }

        ActivityLog::logUser(ActivityLog::ACTION_CREATE, $user, null, [
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $validated['role_id'],
        ]);

        return redirect()->route('users.index')
            ->with('success', __('ui.messages.created', ['item' => $user->name]));
    }

    public function edit(User $user): View
    {
        $this->authorizeAdmin();

        $user->load('vmPermissions');
        $roles = Role::orderBy('name')->get();

        return view('users.edit', compact('user', 'roles'));
    }

    public function update(Request $request, User $user): RedirectResponse
    {
        $this->authorizeAdmin();

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => [
                'required',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($user->id),
            ],
            'role_id' => 'required|exists:roles,id',
            'password' => 'nullable|string|min:4|confirmed',
            'can_create_vm' => 'nullable|boolean',
            'can_delete_vm' => 'nullable|boolean',
            'can_start_vm' => 'nullable|boolean',
            'can_stop_vm' => 'nullable|boolean',
            'can_edit_others_vm' => 'nullable|boolean',
            'can_delete_others_vm' => 'nullable|boolean',
        ]);

        $oldValues = [
            'name' => $user->name,
            'email' => $user->email,
            'role_ids' => $user->roles()->pluck('roles.id')->all(),
        ];

        $user->name = $validated['name'];
        $user->email = $validated['email'];
        if (!empty($validated['password'])) {
            $user->password = Hash::make($validated['password']);
        }
        $user->save();
        $user->roles()->sync([$validated['role_id']]);

        $selectedRole = Role::find($validated['role_id']);
        if ($selectedRole && $selectedRole->slug !== 'administrator') {
            $user->vmPermissions()->updateOrCreate(
                ['user_id' => $user->id],
                [
                    'can_create_vm' => $request->boolean('can_create_vm'),
                    'can_delete_vm' => $request->boolean('can_delete_vm'),
                    'can_start_vm' => $request->boolean('can_start_vm'),
                    'can_stop_vm' => $request->boolean('can_stop_vm'),
                    'can_edit_others_vm' => $request->boolean('can_edit_others_vm'),
                    'can_delete_others_vm' => $request->boolean('can_delete_others_vm'),
                ]
            );
        }

        ActivityLog::logUser(ActivityLog::ACTION_UPDATE, $user, $oldValues, [
            'name' => $user->name,
            'email' => $user->email,
            'role_id' => $validated['role_id'],
            'password_changed' => !empty($validated['password']),
        ]);

        return redirect()->route('users.index')
            ->with('success', __('ui.messages.updated', ['item' => $user->name]));
    }

    public function destroy(User $user): RedirectResponse
    {
        $this->authorizeAdmin();

        $adminRole = Role::where('slug', 'administrator')->first();
        if ($adminRole && $user->roles()->where('roles.id', $adminRole->id)->exists()) {
            $adminCount = User::whereHas('roles', fn($q) => $q->where('roles.id', $adminRole->id))->count();
            if ($adminCount <= 1) {
                return back()->with('error', __('ui.messages.cannot_delete_last_admin'));
            }
        }

        $oldValues = [
            'name' => $user->name,
            'email' => $user->email,
            'role_ids' => $user->roles()->pluck('roles.id')->all(),
        ];

        ActivityLog::logUser(ActivityLog::ACTION_DELETE, $user, $oldValues, null);

        $user->roles()->detach();
        $user->delete();

        return redirect()->route('users.index')
            ->with('success', __('ui.messages.deleted', ['item' => $oldValues['name']]));
    }

    private function authorizeAdmin(): void
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
    }
}
