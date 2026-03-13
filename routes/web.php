<?php

use App\Http\Controllers\Auth\AuthenticatedSessionController;
use App\Http\Controllers\ActivityLogController;
use App\Http\Controllers\BootMediaController;
use App\Http\Controllers\CertificateController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\GroupController;
use App\Http\Controllers\HelpController;
use App\Http\Controllers\LanguageController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\VirtualMachineController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return auth()->check() ? redirect()->route('dashboard') : view('welcome');
});

Route::get('/language/{locale}', [LanguageController::class, 'switch'])
    ->name('language.switch');

Route::middleware('guest')->group(function () {
    Route::get('login', [AuthenticatedSessionController::class, 'create'])
        ->name('login');
    Route::post('login', [AuthenticatedSessionController::class, 'store']);
});

Route::middleware(['auth', \App\Http\Middleware\SetLocaleMiddleware::class])->group(function () {
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');
    Route::get('/dashboard/host-metrics', [DashboardController::class, 'hostMetrics'])->name('dashboard.host-metrics');
    
    Route::post('logout', [AuthenticatedSessionController::class, 'destroy'])
        ->name('logout');

    Route::get('vms/iso-files', [VirtualMachineController::class, 'isoFiles'])->name('vms.iso-files');
    Route::resource('vms', VirtualMachineController::class);
    Route::get('vms/{vm}/preview', [VirtualMachineController::class, 'preview'])->name('vms.preview');
    Route::get('vms/{vm}/console', [VirtualMachineController::class, 'console'])->name('vms.console');
    Route::post('vms/{vm}/send-text', [VirtualMachineController::class, 'sendText'])->name('vms.send-text');
    Route::post('vms/{vm}/start', [VirtualMachineController::class, 'start'])->name('vms.start');
    Route::post('vms/{vm}/stop', [VirtualMachineController::class, 'stop'])->name('vms.stop');
    Route::resource('users', UserController::class)->except(['show']);
    Route::resource('groups', GroupController::class)->except(['show']);
    Route::get('boot-media', [BootMediaController::class, 'index'])->name('boot-media.index');
    Route::post('boot-media', [BootMediaController::class, 'store'])->name('boot-media.store');
    Route::get('boot-media/progress/{operationId}', [BootMediaController::class, 'progress'])->name('boot-media.progress');
    Route::post('boot-media/cancel', [BootMediaController::class, 'cancelMove'])->name('boot-media.cancel');
    Route::delete('boot-media', [BootMediaController::class, 'destroy'])->name('boot-media.destroy');
    Route::get('boot-media/download', [BootMediaController::class, 'download'])->name('boot-media.download');
    Route::get('activity-logs', [ActivityLogController::class, 'index'])->name('activity-logs.index');
    Route::get('activity-logs/trigger-preview', [ActivityLogController::class, 'triggerPreview'])->name('activity-logs.trigger-preview');
    Route::post('activity-logs/clear', [ActivityLogController::class, 'clear'])->name('activity-logs.clear');
    Route::post('activity-logs/clear-service', [ActivityLogController::class, 'clearServiceLog'])->name('activity-logs.clear-service');
    Route::post('activity-logs/clear-all', [ActivityLogController::class, 'clearAll'])->name('activity-logs.clear-all');
    Route::get('certificates', [CertificateController::class, 'index'])->name('certificates.index');
    Route::post('certificates', [CertificateController::class, 'store'])->name('certificates.store');
    Route::get('help', [HelpController::class, 'index'])->name('help.index');
    Route::get('help/docs/{lang}/{file}', [HelpController::class, 'doc'])->name('help.doc')->where('file', '[a-zA-Z0-9_.-]+');
});
