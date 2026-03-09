<?php

namespace App\Http\Controllers;

use App\Models\Group;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\View\View;

class GroupController extends Controller
{
    public function index(): View
    {
        $this->authorizeAdmin();
        $groups = Group::withCount('users')->orderBy('name')->paginate(20);

        return view('groups.index', compact('groups'));
    }

    public function create(): View
    {
        $this->authorizeAdmin();
        return view('groups.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorizeAdmin();
        $validated = $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $slug = Str::slug($validated['name']);
        if (Group::where('slug', $slug)->exists()) {
            return back()->withInput()->withErrors(['name' => __('ui.group.slug_exists')]);
        }

        Group::create([
            'name' => $validated['name'],
            'slug' => $slug,
        ]);

        return redirect()->route('groups.index')
            ->with('success', __('ui.messages.created', ['item' => $validated['name']]));
    }

    public function edit(Group $group): View
    {
        $this->authorizeAdmin();
        $users = \App\Models\User::orderBy('name')->get();
        $group->load('users');

        return view('groups.edit', compact('group', 'users'));
    }

    public function update(Request $request, Group $group): RedirectResponse
    {
        $this->authorizeAdmin();
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'user_ids' => 'nullable|array',
            'user_ids.*' => 'exists:users,id',
        ]);

        $slug = Str::slug($validated['name']);
        $exists = Group::where('slug', $slug)->where('id', '!=', $group->id)->exists();
        if ($exists) {
            return back()->withInput()->withErrors(['name' => __('ui.group.slug_exists')]);
        }

        $group->update(['name' => $validated['name'], 'slug' => $slug]);
        $group->users()->sync($validated['user_ids'] ?? []);

        return redirect()->route('groups.index')
            ->with('success', __('ui.messages.updated', ['item' => $group->name]));
    }

    public function destroy(Group $group): RedirectResponse
    {
        $this->authorizeAdmin();
        $name = $group->name;
        $group->delete();

        return redirect()->route('groups.index')
            ->with('success', __('ui.messages.deleted', ['item' => $name]));
    }

    private function authorizeAdmin(): void
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
    }
}
