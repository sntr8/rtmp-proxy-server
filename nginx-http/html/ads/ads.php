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
    <link rel="stylesheet" type="text/css" href="//cdn.jsdelivr.net/npm/slick-carousel@1.8.1/slick/slick.css"/>
</head>
<body>
    <div class="carousel">
    <?php
        $game = htmlspecialchars($_GET["game"]);

        $dirs = array("img/common/");
        $ads = array();

        if (! empty($game)) {
            array_push($dirs, "img/".$game."/");
        }

        foreach ($dirs as $dir) {
            $images = glob($dir."*.{jpg,png}", GLOB_BRACE);

            foreach($images as $image) {
                array_push($ads, $image);
            }
        }

        shuffle($ads);

        foreach ($ads as $ad) {
            echo "<div><img src=".$ad." /></div>";
        }
    ?>
    </div>
    <script type="text/javascript" src="//code.jquery.com/jquery-1.11.0.min.js"></script>
    <script type="text/javascript" src="//code.jquery.com/jquery-migrate-1.2.1.min.js"></script>
    <script type="text/javascript" src="carousel.js"></script>
    <script type="text/javascript" src="//cdn.jsdelivr.net/npm/slick-carousel@1.8.1/slick/slick.min.js"></script>
</body>
</html>
