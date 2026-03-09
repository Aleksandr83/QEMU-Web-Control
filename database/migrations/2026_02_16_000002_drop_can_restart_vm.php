<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('user_vm_permissions') && Schema::hasColumn('user_vm_permissions', 'can_restart_vm')) {
            Schema::table('user_vm_permissions', function (Blueprint $table) {
                $table->dropColumn('can_restart_vm');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('user_vm_permissions') && !Schema::hasColumn('user_vm_permissions', 'can_restart_vm')) {
            Schema::table('user_vm_permissions', function (Blueprint $table) {
                $table->boolean('can_restart_vm')->default(true)->after('can_stop_vm');
            });
        }
    }
};
