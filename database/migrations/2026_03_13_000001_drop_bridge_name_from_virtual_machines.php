<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('virtual_machines', function (Blueprint $table) {
            $table->dropColumn('bridge_name');
        });
    }

    public function down(): void
    {
        Schema::table('virtual_machines', function (Blueprint $table) {
            $table->string('bridge_name', 64)->nullable()->after('network_type');
        });
    }
};
