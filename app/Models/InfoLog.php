<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InfoLog extends Model
{
    protected $fillable = [
        'service_name',
        'operation_type',
        'method',
        'url',
        'request',
        'response',
        'status_code',
        'error',
    ];

    protected function casts(): array
    {
        return [
            'request' => 'array',
            'response' => 'array',
        ];
    }

    public static function log(
        string $serviceName,
        ?string $method = null,
        ?string $url = null,
        ?array $request = null,
        ?array $response = null,
        ?int $statusCode = null,
        ?string $error = null,
        ?string $operationType = null
    ): self {
        return static::create([
            'service_name' => $serviceName,
            'operation_type' => $operationType,
            'method' => $method,
            'url' => $url,
            'request' => $request,
            'response' => $response,
            'status_code' => $statusCode,
            'error' => $error,
        ]);
    }
}
