<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Kanaliiga Stream Team Ads</title>
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" type="text/css" href="//cdn.jsdelivr.net/npm/slick-carousel@1.8.1/slick/slick.css"/>
</head>
<body>
    <?php
        $location = htmlspecialchars($_GET["location"]);
        $style = "left: -384px;";

        if ($location == "bottom") {
            $style = "top: 216px;";
        } elseif ($location == "top") {
            $style = "top: -216px;";
        } elseif ($location == "right") {
            $style = "left: 384px;";
        }
        echo "<div id=\"streamteam\" style=\"".$style."\">";
    ?>
        <div class="carousel">
            <img class="ad" src="img/streamteam.png" />
        <?php
            $dirs = array("img/ads/");
            $ads = array();

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
                echo "<img class=\"ad\" style=\"display:none;\" src=".$ad." />";
            }
        ?>
            <img class="ad" style="display:none;" src="img/kanaliiga.png" />
        </div>
    </div>
    <script type="text/javascript">//<![CDATA[
    window.onload = function () {
        const queryString = window.location.search;
        const urlParams = new URLSearchParams(queryString);
        $location = urlParams.get('location');
        $test = urlParams.get('test');
        $cooldown = urlParams.get('interval');
        $next = 1;
        $current = 0;
        $interval = 10000;
        $fadeTime = 800;
        $imgNum = $('.ad').length;
        $showtime = $imgNum * $interval + ($imgNum-1) * $fadeTime;
        $hidetime = 120000;

        if ($location == null) {
            $location = "left"
        }

        if ($test == "true") {
            $hidetime = 5000;
        }

        if ($cooldown != null && Number.isInteger(parseInt($cooldown))) {
            $hidetime = parseInt($cooldown)*60*1000;
        }

        function nextFadeIn() {
            $('.carousel img').eq($current).delay($interval).fadeOut($fadeTime).end().eq($next).delay($interval).hide().fadeIn($fadeTime, nextFadeIn);

            if ($next < $imgNum-1) {
                $next++;
            } else {
                $next = 0;
            }
            if ($current < $imgNum-1) {
                $current++;
            } else {
                $current =0;
            }
        }

        function show() {
            if ($location == "left") {
                $('#streamteam').animate( {
                    left: 0
                }, 900);
                setTimeout(function() {
                    hide();
                }, $showtime);
            } else if ($location == "bottom") {
                $('#streamteam').animate( {
                    top: 0
                }, 900);
                setTimeout(function() {
                    hide();
                }, $showtime);
            } else if ($location == "top") {
                $('#streamteam').animate( {
                    top: 0
                }, 900);
                setTimeout(function() {
                    hide();
                }, $showtime);
            } else if ($location == "right") {
                $('#streamteam').animate( {
                    left: 0
                }, 900);
                setTimeout(function() {
                    hide();
                }, $showtime);
            }
        }

        function hide() {
            if ($location == "left") {
                $('#streamteam').animate({
                    left: -384
                }, 900);
                setTimeout(function() {
                    show();
                }, $hidetime);
            } else if ($location == "bottom") {
                $('#streamteam').animate({
                    top: 216
                }, 900);
                setTimeout(function() {
                    show();
                }, $hidetime);
            } else if ($location == "top") {
                $('#streamteam').animate({
                    top: -216
                }, 900);
                setTimeout(function() {
                    show();
                }, $hidetime);
            } else if ($location == "right") {
                $('#streamteam').animate({
                    left: 384
                }, 900);
                setTimeout(function() {
                    show();
                }, $hidetime);
            }
        }

        $('.carousel').css('position','relative');
        $('.carousel img').css({'position':'absolute','width':'384px','height':'216px'});
        nextFadeIn();
        hide();
    }
    //]]></script>
    <script language="JavaScript" type="text/javascript" src="//code.jquery.com/jquery-2.2.4.min.js"></script>
</body>
</html>
