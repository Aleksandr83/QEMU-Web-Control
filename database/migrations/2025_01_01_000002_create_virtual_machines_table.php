<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('virtual_machines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->text('description')->nullable();
            $table->string('uuid')->unique();
            
            $table->integer('cpu_cores')->default(2);
            $table->integer('ram_mb')->default(2048);
            $table->string('disk_path')->nullable();
            $table->integer('disk_size_gb')->default(20);
            
            $table->string('os_type')->nullable();
            $table->string('iso_path')->nullable();
            
            $table->string('network_type')->default('user');
            $table->string('mac_address')->nullable();
            $table->integer('vnc_port')->nullable();
            
            $table->enum('status', ['stopped', 'running', 'paused', 'error'])->default('stopped');
            $table->integer('pid')->nullable();
            
            $table->json('extra_params')->nullable();
            
            $table->timestamp('last_started_at')->nullable();
            $table->timestamp('last_stopped_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('virtual_machines');
    }
};
