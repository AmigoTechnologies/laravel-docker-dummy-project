<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

Schedule::call(function () {
    info('Test from scheduler every 1min '.now()->format('d/m/Y H:i:s'));
})->everyMinute();

Schedule::call(function () {
    info('Test from scheduler every 5sec ' . now()->format('d/m/Y H:i:s'));
})->everyFiveSeconds();
