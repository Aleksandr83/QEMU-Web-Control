<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VirtualMachineDisk extends Model
{
    use HasFactory;

    protected $fillable = [
        'virtual_machine_id',
        'path',
        'size_gb',
        'interface',
        'boot_order',
    ];

    public function virtualMachine()
    {
        return $this->belongsTo(VirtualMachine::class);
    }
}
