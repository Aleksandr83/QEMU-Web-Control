<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vm_group_shares', function (Blueprint $table) {
            $table->foreignId('virtual_machine_id')->constrained()->cascadeOnDelete();
            $table->foreignId('group_id')->constrained()->cascadeOnDelete();
            $table->primary(['virtual_machine_id', 'group_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vm_group_shares');
    }
};
