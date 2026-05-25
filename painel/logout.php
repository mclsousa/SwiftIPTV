<?php
require_once __DIR__ . '/includes/auth.php';
logout_operator();
header('Location: login.php');
exit;
