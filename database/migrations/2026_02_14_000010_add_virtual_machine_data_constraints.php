<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('virtual_machines', function (Blueprint $table) {
            $table->unique('vnc_port', 'virtual_machines_vnc_port_unique');
        });

        $driver = DB::getDriverName();
        if (!in_array($driver, ['mysql', 'pgsql'], true)) {
            return;
        }

        DB::statement('ALTER TABLE virtual_machines ADD CONSTRAINT chk_vm_cpu_cores_range CHECK (cpu_cores BETWEEN 1 AND 32)');
        DB::statement('ALTER TABLE virtual_machines ADD CONSTRAINT chk_vm_ram_range CHECK (ram_mb BETWEEN 512 AND 65536)');
        DB::statement('ALTER TABLE virtual_machines ADD CONSTRAINT chk_vm_disk_size_range CHECK (disk_size_gb BETWEEN 1 AND 1000)');
        DB::statement('ALTER TABLE virtual_machines ADD CONSTRAINT chk_vm_vnc_port_range CHECK (vnc_port IS NULL OR (vnc_port BETWEEN 5900 AND 5999))');
    }

    public function down(): void
    {
        $driver = DB::getDriverName();
        if ($driver === 'mysql') {
            DB::statement('ALTER TABLE virtual_machines DROP CHECK chk_vm_cpu_cores_range');
            DB::statement('ALTER TABLE virtual_machines DROP CHECK chk_vm_ram_range');
            DB::statement('ALTER TABLE virtual_machines DROP CHECK chk_vm_disk_size_range');
            DB::statement('ALTER TABLE virtual_machines DROP CHECK chk_vm_vnc_port_range');
        } elseif ($driver === 'pgsql') {
            DB::statement('ALTER TABLE virtual_machines DROP CONSTRAINT chk_vm_cpu_cores_range');
            DB::statement('ALTER TABLE virtual_machines DROP CONSTRAINT chk_vm_ram_range');
            DB::statement('ALTER TABLE virtual_machines DROP CONSTRAINT chk_vm_disk_size_range');
            DB::statement('ALTER TABLE virtual_machines DROP CONSTRAINT chk_vm_vnc_port_range');
        }

        Schema::table('virtual_machines', function (Blueprint $table) {
            $table->dropUnique('virtual_machines_vnc_port_unique');
        });
    }
};
