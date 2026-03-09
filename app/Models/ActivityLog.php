<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Request;

class ActivityLog extends Model
{
    use HasFactory;

    public const TYPE_USER = 'user';
    public const TYPE_ROLE = 'role';
    public const TYPE_VM = 'vm';
    public const TYPE_SETTINGS = 'settings';
    public const TYPE_CERTIFICATE = 'certificate';
    public const TYPE_BOOT_MEDIA = 'boot_media';
    public const TYPE_ERROR = 'error';

    public const ACTION_CREATE = 'create';
    public const ACTION_UPDATE = 'update';
    public const ACTION_DELETE = 'delete';
    public const ACTION_START = 'start';
    public const ACTION_STOP = 'stop';
    public const ACTION_RESTART = 'restart';
    public const ACTION_START_FAILED = 'start_failed';

    protected $fillable = [
        'user_id',
        'type',
        'action',
        'subject_type',
        'subject_id',
        'subject_name',
        'old_values',
        'new_values',
        'ip_address',
        'server_id',
        'user_agent',
    ];

    protected function casts(): array
    {
        return [
            'old_values' => 'array',
            'new_values' => 'array',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public static function log(
        string $type,
        string $action,
        ?string $subjectType = null,
        ?int $subjectId = null,
        ?string $subjectName = null,
        ?array $oldValues = null,
        ?array $newValues = null
    ): self {
        return static::create([
            'user_id' => Auth::id(),
            'type' => $type,
            'action' => $action,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'subject_name' => $subjectName,
            'old_values' => $oldValues,
            'new_values' => $newValues,
            'ip_address' => Request::ip(),
            'server_id' => Setting::serverId(),
            'user_agent' => Request::userAgent(),
        ]);
    }

    public static function logUser(string $action, User $user, ?array $old = null, ?array $new = null): self
    {
        return static::log(self::TYPE_USER, $action, User::class, $user->id, $user->name, $old, $new);
    }

    public static function logVm(string $action, VirtualMachine $vm, ?array $old = null, ?array $new = null): self
    {
        return static::log(self::TYPE_VM, $action, VirtualMachine::class, $vm->id, $vm->name, $old, $new);
    }

    public static function logVmError(VirtualMachine $vm, string $message, string $action = self::ACTION_START_FAILED, array $details = []): self
    {
        return static::log(
            self::TYPE_ERROR,
            $action,
            VirtualMachine::class,
            $vm->id,
            $vm->name,
            null,
            array_merge(['message' => $message], $details)
        );
    }
}
