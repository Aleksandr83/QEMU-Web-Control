<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('users') && Schema::hasColumn('users', 'can_create_vm')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn([
                    'can_create_vm',
                    'can_delete_vm',
                    'can_start_vm',
                    'can_stop_vm',
                ]);
            });
        }

        Schema::create('user_vm_permissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->boolean('can_create_vm')->default(true);
            $table->boolean('can_delete_vm')->default(true);
            $table->boolean('can_start_vm')->default(true);
            $table->boolean('can_stop_vm')->default(true);
            $table->timestamps();

            $table->unique('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_vm_permissions');
    }
};
