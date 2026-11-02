<?php
// Opening http://localhost/tala_api/ in a browser shows whether the API and database are working.
$_GET['action'] = 'ping';
require __DIR__ . '/api.php';
