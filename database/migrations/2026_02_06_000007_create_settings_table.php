<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('vm_server_id');
            $table->string('parameter_name');
            $table->text('value')->nullable();
            $table->timestamps();

            $table->unique(['vm_server_id', 'parameter_name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('settings');
    }
};
