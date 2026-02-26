<html>
<head>
    <script src="https://code.jquery.com/jquery-3.2.1.min.js"></script>
    <title>Kanaliiga PUBG OBS Overlay: sponsors</title>
    <style>
        body {
            overflow: hidden;
        }
        .scene {
            width: 1920px;
            height: 1080px;
        }
        .sponsors {
            position: absolute;
            top: 970px;
            left: 340px;
            #border-style: solid;
            width: 1300px;
            height: 130px;
        }
        .grid {
          display: flex;
          position: absolute;
          left: 10%;
        }
        .grid img {
          padding-left: 15px;
          padding-right: 15px;
          padding-top: 30px;
          max-height: 70px;
          max-width: 300px;
          height: auto;
          width: auto;
        }
        .grid-item {
            display: flex;
            align-items: center;
        }
        img.ad {
            position: absolute;
        }
    </style>
</head>
<body onload="createPage()">
    <div class="scene">
        <div class="sponsors">
            <div class="grid">
                <?php
                $ads = array();
                $first = True;
                foreach(file("sponsor-imgs.txt") as $img) {

                    if (str_contains($img, "/main_")) {
                        echo "<div class=\"grid-item\"><img src=\"".$img."\" /></div>";
                    } else {
                        array_push($ads, $img);
                    }
                }
                shuffle($ads);

                foreach ($ads as $ad) {
                    $style = "style=\"display:none;\"";
                    if ($first) {
                        $style = "style";
                        $first = False;
                    }
                    echo "<div class=\"grid-item\"><img class=\"ad\" ".$style." src=".$ad." /></div>";
                }
                ?>
            </div>
        </div>
    </div>
    <script>
        function createPage() {
            $next = 1;
            $current = 0;
            $interval = 10000;
            $fadeTime = 800;
            $imgNum = $('.ad').length;
            function nextFadeIn() {

                $('.grid img.ad').eq($current).delay($interval).fadeOut($fadeTime).end().eq($next).delay($interval).hide().fadeIn($fadeTime, nextFadeIn);

                if ($next < $imgNum-1) {
                    $next++;
                } else {
                    $next = 0;
                }
                if ($current < $imgNum-1) {
                    $current++;
                } else {
                    $current = 0;
                }
            }
            nextFadeIn()
        }
    </script>
</body>
</html>
