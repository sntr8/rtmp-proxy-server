<?php
$servername = "mysql";
$username = getenv("MYSQL_USER");
$password = getenv("MYSQL_PASSWORD");
$dbname = getenv("MYSQL_DATABASE");

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
    http_response_code(500);
    exit;
}

$namesql = "SELECT stream_key FROM casters WHERE active = true";
$nameresult = $conn->query($namesql);

if (!$nameresult) {
    http_response_code(500);
    $conn->close();
    exit;
}

$expectedNames = [];

while($row = mysqli_fetch_assoc($nameresult)) {
    foreach ($row as $key => $value) {
        $expectedNames[] = $value;
    }

}

$nameresult->close();

if(!in_array($_POST["name"], $expectedNames)){
    http_response_code(401);
    $conn->close();
    exit;
}

$appsql = "SELECT nick FROM casters WHERE active = true AND internal = false";
$appresult = $conn->query($appsql);

if (!$appresult) {
    http_response_code(500);
    $conn->close();
    exit;
}

$expectedApps = [];

while($row = mysqli_fetch_assoc($appresult)) {
    foreach ($row as $key => $value) {
        $expectedApps[] = $value;
        $expectedApps[] = $value."-publish";
    }

}

$appresult->close();
$conn->close();

if(!in_array($_POST["app"], $expectedApps)){
    http_response_code(404);
    exit;
}

$expectedCalls = array("publish", "play", "update");

if(!in_array($_POST["call"], $expectedCalls)){
    http_response_code(400);
    exit;
}

?>
