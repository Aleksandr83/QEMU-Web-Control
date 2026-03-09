<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;

class VirtualMachine extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'shared_with_all',
        'name',
        'description',
        'uuid',
        'vm_id',
        'cpu_cores',
        'ram_mb',
        'disk_path',
        'disk_size_gb',
        'os_type',
        'architecture',
        'iso_path',
        'network_type',
        'mac_address',
        'vnc_port',
        'status',
        'autostart',
        'use_audio',
        'pid',
        'extra_params',
        'last_started_at',
        'last_stopped_at',
    ];

    protected function casts(): array
    {
        return [
            'shared_with_all' => 'boolean',
            'autostart' => 'boolean',
            'use_audio' => 'boolean',
            'extra_params' => 'array',
            'last_started_at' => 'datetime',
            'last_stopped_at' => 'datetime',
        ];
    }

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($vm) {
            if (empty($vm->uuid)) {
                $vm->uuid = (string) Str::uuid();
            }
            if (empty($vm->mac_address)) {
                $vm->mac_address = self::generateMacAddress();
            }
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function sharedUsers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'vm_user_shares');
    }

    public function sharedGroups(): BelongsToMany
    {
        return $this->belongsToMany(Group::class, 'vm_group_shares');
    }

    public function disks()
    {
        return $this->hasMany(VirtualMachineDisk::class)->orderBy('boot_order');
    }

    public static function scopeVisibleFor(Builder $query, User $user): Builder
    {
        if ($user->isAdmin()) {
            return $query;
        }

        $groupIds = $user->groups()->pluck('groups.id')->all();

        return $query->where(function (Builder $q) use ($user, $groupIds) {
            $q->where('user_id', $user->id)
                ->orWhere('shared_with_all', true)
                ->orWhereHas('sharedUsers', fn (Builder $b) => $b->where('users.id', $user->id));
            if ($groupIds !== []) {
                $q->orWhereHas('sharedGroups', fn (Builder $b) => $b->whereIn('groups.id', $groupIds));
            }
        });
    }

    public function hasAccess(User $user): bool
    {
        if ($user->isAdmin()) {
            return true;
        }
        if ($this->user_id === $user->id) {
            return true;
        }
        if ($this->shared_with_all) {
            return true;
        }
        if ($this->sharedUsers()->where('users.id', $user->id)->exists()) {
            return true;
        }
        $userGroupIds = $user->groups()->pluck('groups.id');
        if ($userGroupIds->isNotEmpty() && $this->sharedGroups()->whereIn('groups.id', $userGroupIds)->exists()) {
            return true;
        }
        return false;
    }

    public function isRunning(): bool
    {
        return $this->status === 'running';
    }

    public function isStopped(): bool
    {
        return $this->status === 'stopped';
    }

    private static function generateMacAddress(): string
    {
        return sprintf(
            '52:54:00:%02x:%02x:%02x',
            rand(0, 255),
            rand(0, 255),
            rand(0, 255)
        );
    }
}
