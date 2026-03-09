<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'locale',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function vmPermissions(): HasOne
    {
        return $this->hasOne(UserVmPermissions::class);
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class)->withTimestamps();
    }

    public function hasRole(string $slug): bool
    {
        return $this->roles()->where('slug', $slug)->exists();
    }

    public function isAdmin(): bool
    {
        return $this->hasRole('administrator');
    }

    public function virtualMachines()
    {
        return $this->hasMany(VirtualMachine::class);
    }

    public function groups(): BelongsToMany
    {
        return $this->belongsToMany(Group::class, 'group_user');
    }

    public function sharedVirtualMachines(): BelongsToMany
    {
        return $this->belongsToMany(VirtualMachine::class, 'vm_user_shares');
    }

    public function canCreateVm(): bool
    {
        return $this->isAdmin() || ($this->vmPermissions?->can_create_vm ?? true);
    }

    public function canDeleteVm(): bool
    {
        return $this->isAdmin() || ($this->vmPermissions?->can_delete_vm ?? true);
    }

    public function canStartVm(): bool
    {
        return $this->isAdmin() || ($this->vmPermissions?->can_start_vm ?? true);
    }

    public function canStopVm(): bool
    {
        return $this->isAdmin() || ($this->vmPermissions?->can_stop_vm ?? true);
    }

    public function canEditOthersVm(): bool
    {
        return $this->isAdmin() || ($this->vmPermissions?->can_edit_others_vm ?? false);
    }

    public function canDeleteOthersVm(): bool
    {
        return $this->isAdmin() || ($this->vmPermissions?->can_delete_others_vm ?? false);
    }
}
