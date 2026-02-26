<html>
    <head>
        <title>Kanaliiga PUBG OBS Overlay: in-game</title>
        <script src="https://code.jquery.com/jquery-3.2.1.min.js"></script>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@400;500&display=swap');
            body {
                overflow: hidden;
            }
            .scene {
                width: 1920px;
                height: 1080px;
            }
            .headline {
                position: absolute;
                top: 24px;
                left: 24px;
            }
            h1,h2 {
                font-family: 'Big Shoulders Display', sans-serif;
                text-transform: uppercase;
                font-size: 30px;
                text-align: center;
            }
            h1 {
                color: #282728;
            }
            h2 {
                color: #ffffff;
            }
            .h1box {
                position: absolute;
                top: -10px;
                left: 5px;
                width: 263px;
            }
            .h2box {
                position: absolute;
                top: 40px;
                left: 5px;
                width: 263px;
            }
            .sponsors {
                position: absolute;
                top: 610px;
                right: 20px;
            }
            img.ad {
                position: absolute;
                max-width: 257px;
                right: 13px;
                height: auto;
            }
            span {
                color: #f29209;
            }
        </style>
    </head>
    <body onload="createPage()">
        <div id="scene" class="scene">
            <div id="headline" class="headline">
                <img src="img/in-game/headline.png"/>
                <div id="h1box" class="h1box">
                </div>
                <div id="h2box" class="h2box">
                </div>
            </div>
            <div id="sponsors" class="sponsors">
                <div class="carousel">
                <?php
                    $tournament = file_get_contents('https://dev.kanaliiga.fi/tournament.txt');
                    $dir = "img/in-game/";
                    echo "<img class=\"ad\" style src=\"".$dir.$tournament.".png\" />";
                    $ads = array();
                    $valid_ext = array("jpg", "jpeg", "png");

                    foreach (new DirectoryIterator($dir."sponsors/") as $fileInfo) {
                        $fileName = $fileInfo->getFilename();
                        if (in_array($fileInfo->getExtension(), $valid_ext)) {
                            array_push($ads, $dir."sponsors/".$fileInfo->getFilename());

                        }
                    }

                    asort($ads);

                    foreach ($ads as $ad) {
                        echo "<img class=\"ad\" style=\"display:none;\" src=\"".$ad."\" />";
                    }
                ?>
                    <img class="ad" style="display:none;" src="img/in-game/kanastats.png" />
                    <img class="ad" style="display:none;" src="img/in-game/partner-logo.png" />
<!--                    <img class="ad" style="display:none;" src="img/in-game/creatorcode.png" /> -->
                </div>
            </div>
        </div>
        <script>
            function createPage() {
                var queryString = window.location.search;
                var urlParams = new URLSearchParams(queryString);
                var group = urlParams.get('league');
                var origJson = null;
                $.get('https://dev.kanaliiga.fi/tournament.txt', function(tournament) {
                    var randomStr = new Date().getTime();
                    $.getJSON('https://dev.kanaliiga.fi/gameday.json?rndstr='+randomStr, function(json) {
                        origJson = JSON.stringify(json);
                        var sponsors = document.getElementById("sponsors");
                        var h1box = document.getElementById("h1box");
                        var h2box = document.getElementById("h2box");
                        var tournamenth1 = document.createElement("h1");
                        var tournamenth2 = document.createElement("h2");
                        $(json.gameDays).each(function(index, groupJson) {
                            if (!group || groupJson.key == group) {
                                if (!group) {
                                    group = groupJson.key;
                                }
                                var currentDayPlayedMaps = groupJson.currentDayPlayedMaps + 1;
                                var currentMatchDay = groupJson.currentMatchDay;
                                var dayCount = groupJson.allMatchDates.length;
                                var mapCount = groupJson.maps.length;
                                tournamenth1.appendChild(document.createTextNode(groupJson.league));
                                if (currentDayPlayedMaps > mapCount) {
                                    currentDayPlayedMaps = mapCount;
                                }
                                tournamenth2.innerHTML = "DAY "+currentMatchDay+"/"+dayCount+"<span>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;</span>MAP "+currentDayPlayedMaps+"/"+mapCount;
                                h1box.appendChild(tournamenth1);
                                h2box.appendChild(tournamenth2);
                                return false;
                            } else {
                                console.log("League '"+group+"' not found");
                            }
                        });
                    });
                });

                $next = 1;
                $current = 0;
                $logoInterval = 45000;
                $adInterval = 5000;
                $interval = $logoInterval;
                $fadeTime = 800;
                $imgNum = $('.ad').length;
                function nextFadeIn() {

                    $('.carousel img').eq($current).delay($interval).fadeOut($fadeTime).end().eq($next).delay($interval).hide().fadeIn($fadeTime, nextFadeIn);

                    if ($next < $imgNum-1) {
                        $next++;
                    } else {
                        $next = 0;
                    }
                    if ($current < $imgNum-1) {
                        $current++;
                        $interval = $adInterval;
                    } else {
                        $current = 0;
                        $interval = $logoInterval;
                    }
                }
                nextFadeIn()

                setInterval(function() {
                    $.getJSON('https://dev.kanaliiga.fi/gameday.json?rndstr='+new Date().getTime(), function(json) {
                        current = JSON.stringify(json);
                        if (origJson && current && origJson !== current) {
                            location.reload();
                        }
                    });
                }, 60000);
            }
        </script>
    </body>
</html>
