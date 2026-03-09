<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('virtual_machines', function (Blueprint $table) {
            $table->boolean('enable_kvm')->default(true)->after('use_audio');
        });
    }

    public function down(): void
    {
        Schema::table('virtual_machines', function (Blueprint $table) {
            $table->dropColumn('enable_kvm');
        });
    }
};
