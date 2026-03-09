<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserVmPermissions extends Model
{
    protected $table = 'user_vm_permissions';

    protected $fillable = [
        'user_id',
        'can_create_vm',
        'can_delete_vm',
        'can_start_vm',
        'can_stop_vm',
        'can_edit_others_vm',
        'can_delete_others_vm',
    ];

    protected function casts(): array
    {
        return [
            'can_create_vm' => 'boolean',
            'can_delete_vm' => 'boolean',
            'can_start_vm' => 'boolean',
            'can_stop_vm' => 'boolean',
            'can_edit_others_vm' => 'boolean',
            'can_delete_others_vm' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
