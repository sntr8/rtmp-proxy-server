<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <?php
        $game = htmlspecialchars($_GET["game"]);
        if (empty($game)) {
            echo "<title>Kanaliiga Common Ads</title>";
        } else {
            echo "<title>Kanaliiga ".strtoupper($game)." Ads</title>";
        }
    ?>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="carousel">
    <?php
        $game = htmlspecialchars($_GET["game"]);

        $dirs = array("img/common/");
        $ads = array();

        if (! empty($game) ) {
            if (file_exists("img/".$game."/")) {
                array_push($dirs, "img/".$game."/");
            }
        }

        $valid_ext = array("jpg", "jpeg", "png");

        foreach ($dirs as $dir) {
            foreach (new DirectoryIterator($dir) as $fileInfo) {
                if (in_array($fileInfo->getExtension(), $valid_ext) ) {
                    array_push($ads, $dir.$fileInfo->getFilename());
                }
            }
        }

        shuffle($ads);

        foreach ($ads as $ad) {
            echo "<div class=\"carousel-slide\"><img src=".$ad." /></div>";
        }
    ?>
    </div>
    <script type="text/javascript" src="carousel.js"></script>
</body>
</html>
