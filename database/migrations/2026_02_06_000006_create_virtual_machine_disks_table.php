<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('virtual_machine_disks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('virtual_machine_id')->constrained()->cascadeOnDelete();
            $table->string('path');
            $table->unsignedInteger('size_gb');
            $table->string('interface')->default('virtio');
            $table->unsignedInteger('boot_order')->default(1);
            $table->timestamps();
        });

        $legacyVms = DB::table('virtual_machines')
            ->select('id', 'disk_path', 'disk_size_gb', 'uuid')
            ->get();

        foreach ($legacyVms as $vm) {
            $path = $vm->disk_path ?: '/var/lib/qemu/vms/' . $vm->uuid . '.qcow2';
            $size = (int) ($vm->disk_size_gb ?: 20);
            DB::table('virtual_machine_disks')->insert([
                'virtual_machine_id' => $vm->id,
                'path' => $path,
                'size_gb' => $size,
                'interface' => 'virtio',
                'boot_order' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('virtual_machine_disks');
    }
};
