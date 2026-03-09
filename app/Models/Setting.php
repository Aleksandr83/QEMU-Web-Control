<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    protected $fillable = ['vm_server_id', 'parameter_name', 'value'];

    public static function get(string $parameterName, ?string $default = null): ?string
    {
        $serverId = self::serverId();
        if ($serverId === null) {
            return $default;
        }

        $row = static::where('vm_server_id', $serverId)
            ->where('parameter_name', $parameterName)
            ->first();

        return $row?->value ?? $default;
    }

    public static function set(string $parameterName, string $value): self
    {
        $serverId = self::serverId();
        if ($serverId === null) {
            throw new \RuntimeException('Server ID not found. Ensure /etc/QemuWebControl/id exists and is readable.');
        }

        return static::updateOrCreate(
            ['vm_server_id' => $serverId, 'parameter_name' => $parameterName],
            ['value' => $value]
        );
    }

    public static function serverId(): ?string
    {
        $path = '/etc/QemuWebControl/id';
        if (!is_readable($path)) {
            return null;
        }

        $id = @file_get_contents($path);
        return $id !== false ? trim($id) : null;
    }
}
