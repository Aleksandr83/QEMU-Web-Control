<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_vm_permissions', function (Blueprint $table) {
            $table->boolean('can_edit_others_vm')->default(false)->after('can_stop_vm');
            $table->boolean('can_delete_others_vm')->default(false)->after('can_edit_others_vm');
        });
    }

    public function down(): void
    {
        Schema::table('user_vm_permissions', function (Blueprint $table) {
            $table->dropColumn(['can_edit_others_vm', 'can_delete_others_vm']);
        });
    }
};
