<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vm_user_shares', function (Blueprint $table) {
            $table->foreignId('virtual_machine_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->primary(['virtual_machine_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vm_user_shares');
    }
};
