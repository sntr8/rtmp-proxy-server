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

// Extract base app name (remove -publish suffix if present)
$baseApp = preg_replace('/-publish$/', '', $_POST["app"]);

// Verify the stream_key belongs to the caster who owns this context
$authsql = "SELECT COUNT(*) as count FROM casters
            WHERE active = true
            AND stream_key = ?
            AND nick = ?
            AND (internal = false OR ? LIKE '%-publish')";

$stmt = $conn->prepare($authsql);

if (!$stmt) {
    http_response_code(500);
    $conn->close();
    exit;
}

$stmt->bind_param("sss", $_POST["name"], $baseApp, $_POST["app"]);
$stmt->execute();
$result = $stmt->get_result();

if (!$result) {
    http_response_code(500);
    $stmt->close();
    $conn->close();
    exit;
}

$row = $result->fetch_assoc();

if ($row['count'] == 0) {
    http_response_code(401);
    $stmt->close();
    $conn->close();
    exit;
}

$stmt->close();
$conn->close();

$expectedCalls = array("publish", "play", "update");

if(!in_array($_POST["call"], $expectedCalls)){
    http_response_code(400);
    exit;
}

?>
