<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('info_logs', function (Blueprint $table) {
            $table->string('operation_type', 50)->nullable()->after('service_name');
            $table->index('operation_type');
        });
    }

    public function down(): void
    {
        Schema::table('info_logs', function (Blueprint $table) {
            $table->dropIndex(['operation_type']);
            $table->dropColumn('operation_type');
        });
    }
};
