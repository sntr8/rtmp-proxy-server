<html>
    <head>
        <title>Kanaliiga PUBG OBS Overlay: break</title>
        <script src="https://code.jquery.com/jquery-3.2.1.min.js"></script>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@400;500;600;700&display=swap');
            @font-face {
              font-family: "7segment";
              src: url('fonts/7segment.woff');
            }
            body {
                overflow: hidden;
            }
            img.todaylogo {
                height: 75px;
            }
            img.winnerlogo {
                margin-top: 10px;
                height: 105px;
            }
            .abbr {
                font-family: 'Big Shoulders Display', sans-serif;
                font-weight: 400;
                color: #f29209;
                font-size: 25px;
                width: 100%;
                text-align: center;
            }
            .scene {
                width: 1920px;
                height: 1080px;
            }
            .teamstoday {
                position: absolute;
                top: 440px;
                left: 0px;
                width: 380px;
            }
            .logos {
                display: grid;
                grid-template-columns: repeat(4, 77px);
                grid-template-rows: repeat(4, 90px);
                grid-gap: 15px;
                width: 90%;
                margin-left: 15px;
            }
            h1,h2 {
                font-family: 'Big Shoulders Display', sans-serif;
                font-weight: 700;
                text-transform: uppercase;
                color: #f29209;
                font-size: 41px;
                text-align: center;
            }
            .h1box {
                position: absolute;
                top: 220px;
                left: 0px;
                width: 380px;
            }
            .h2box {
                position: absolute;
                top: 270px;
                left: 0px;
                width: 380px;
            }
            .maps {
                position: absolute;
                top: 868px;
                left: 380px;
                width: 1200px;
                height: 230px;
                display: grid;
                grid-template-columns: repeat(6, 213px);
                width: 90%;
                text-transform: uppercase;
                font-family: 'Big Shoulders Display', sans-serif;
                color: #f29209;
            }
            .number {
                font-size: 30px;
                margin-top: 5px;
            }
            .startTime,.winnerText {
                margin-top: 20px;
                font-size: 30px;
            }
            .winnerMap {
                margin-top: 10px;
                font-size: 30px;
            }
            .mapname {
                margin-top: 30px;
                font-size: 60px;
                font-weight: 600;
            }
            .next {
                color: #000000;
                background-color: #f29209;
            }
            .map {
                overflow: auto;
                height: 230px;
                width: 210px;
                text-align: center;
                border-width: 3px;
                border-style: solid;
                border-image: linear-gradient(to bottom,#f29209,rgba(0, 0, 0, 0)) 1 100%;
            }
            .sponsorbox {
                position: absolute;
                top: 905px;
                right: 10px;
                width: 240px;
                height: 200px;
            }
            .partnerborder {
                position: absolute;
                top: 868px;
                right: 259px;
                border-left-width: 3px;
                border-left: solid;
                border-image: linear-gradient(to bottom,#f29209,rgba(0, 0, 0, 0)) 1 100%;
                height: 230px;
            }
            img.ad {
                position: absolute;
                margin-top: 30px;
            }
            .sponsortitle {
                position: absolute;
                top: 870px;
                right: 165px;
                font-family: 'Big Shoulders Display', sans-serif;
                font-weight: 500;
                color: #f29209;
                font-size: 30px;
            }
            .sponsorbox .grid-item img {
                max-width: 235px;
                max-height: 110px;
                height: auto;
                width: auto;
            }
            .grid-item {
                display: flex;
                justify-content: center;
            }
            .counterbox {
                position: absolute;
                top: 868px;
                width: 360px;
                display: none;
            }
            .countertext {
                font-family: 'Big Shoulders Display', sans-serif;
                font-weight: 700;
                color: #f29209;
                text-transform: uppercase;
                font-size: 40px;
                margin-top: 16px;
                width: 100%;
                text-align: center;
            }
            .counter {
                font-family: '7segment';
                width: 100%;
                text-align: center;
                font-size: 140px;
                margin-top: 9px;
                color: white;
            }
        </style>
    </head>
    <body onload="createPage()">
        <div id="scene" class="scene">
            <div id="headline" class="headline">
                <div id="h1box" class="h1box">
                </div>
                <div id="h2box" class="h2box">
                </div>
            </div>
            <div id="teamstoday" class="teamstoday">
                <div id="logos" class="logos">
                </div>
            </div>
            <div id="counterbox" class="counterbox">
                <div class="countertext">Next Map In</div>
                <div id="counter" class="counter"></div>
            </div>
            <div id="maps" class="maps">
            </div>
            <div class="partnerborder"></div>
            <div class="sponsortitle">Partners:</div>
            <div id="sponsorbox" class="sponsorbox">
                <?php
                $ads = array();
                $first = True;
                foreach(file("sponsor-imgs.txt") as $img) {
                    array_push($ads, $img);
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
        <script>
            function createPage() {
                var queryString = window.location.search;
                var urlParams = new URLSearchParams(queryString);
                var group = urlParams.get('league');
                var tournament = null;
                var origJson = null;
                $.get('https://dev.kanaliiga.fi/tournament.txt', function(tournamentFromFile) {
                    tournament = tournamentFromFile;
                    var randomStr = new Date().getTime();
                    $.getJSON('https://dev.kanaliiga.fi/gameday.json?rndstr='+randomStr, function(json) {
                        origJson = JSON.stringify(json);
                        var logos = document.getElementById("logos");
                        var maps = document.getElementById("maps");
                        var h1box = document.getElementById("h1box");
                        var h2box = document.getElementById("h2box");
                        var tournamenth1 = document.createElement("h1");
                        var tournamenth2 = document.createElement("h2");
                        var tournamentName = json.name.replace("Kanaliiga ", "");
                        $(json.gameDays).each(function(index, groupJson) {
                            if (!group || groupJson.key == group) {
                                if (!group) {
                                    group = groupJson.key;
                                }
                                console.log(group);
                                $.getJSON('https://dev.kanaliiga.fi/obs-teamlogos/'+tournament+'/'+group+'/abbreviations.txt?rndstr='+randomStr, function(abbrs) {
                                    var league = groupJson.league;
                                    if (tournamentName.toLowerCase().endsWith("qualifiers") && league.toLowerCase().endsWith("qualifiers")) {
                                        tournamentName = tournamentName.toLowerCase().replace("qualifiers", "");
                                    }
                                    tournamenth1.appendChild(document.createTextNode(tournamentName));
                                    tournamenth2.appendChild(document.createTextNode(league));
                                    h1box.appendChild(tournamenth1)
                                    h2box.appendChild(tournamenth2);
                                    $.each(abbrs, function(abbrSlot, abbr) {
                                        var teambox = document.createElement("div");
                                        teambox.className = "teambox"
                                        var logoImg = document.createElement("img");
                                        logoImg.src = "https://dev.kanaliiga.fi/obs-teamlogos/"+tournament+"/"+group+"/"+Object.keys(abbr)[0]+".png";
                                        logoImg.className = "todaylogo";
                                        teambox.appendChild(logoImg);
                                        var abbrDiv = document.createElement("div");
                                        abbrDiv.className = "abbr"
                                        /*FIXME: Does not handle full lobbies*/
                                        abbrDiv.appendChild(document.createTextNode(Object.values(abbr)[0]));
                                        teambox.appendChild(abbrDiv);
                                        logos.appendChild(teambox);
                                    });
                                    var dayStartTime = groupJson.startTime;
                                    var i = 1;
                                    var alreadyNext = false;
                                    var mapList = groupJson.maps;
                                    var mapCount = mapList.length;
                                    if (mapCount == 4) {
                                        maps.style.left = "593px"
                                    }
                                    $.each(groupJson.currentDayMapWinners, function(index, mapJson) {
                                        var name = mapJson.map;
                                        var winnerJson = mapJson.winner;
                                        var mapDiv = document.createElement("div");
                                        mapDiv.className = "map"
                                        var numberDiv = document.createElement("div");
                                        numberDiv.className = "number";
                                        if (winnerJson != null) {
                                            numberDiv.appendChild(document.createTextNode("winner"));
                                            mapDiv.appendChild(numberDiv);
                                            var winnerslot = winnerJson.teamId;
                                            var fragCount = winnerJson.kills;
                                            var img = document.createElement("img");
                                            img.src = "https://dev.kanaliiga.fi/obs-teamlogos/"+tournament+"/"+group+"/"+winnerslot+".png";
                                            img.className = "winnerlogo";
                                            mapDiv.appendChild(img);
                                            var winnerMap = document.createElement("div");
                                            winnerMap.className = "winnerMap";
                                            winnerMap.appendChild(document.createTextNode(name));
                                            mapDiv.appendChild(winnerMap);
                                        } else {
                                            var dayNumber = groupJson.currentMatchDay;
                                            var matchNumberStr = (dayNumber - 1) * mapCount + i;
                                            numberDiv.appendChild(document.createTextNode("Map "+matchNumberStr));
                                            mapDiv.appendChild(numberDiv);
                                            if (!alreadyNext) {
                                                mapDiv.className = "next map";
                                                alreadyNext = true;
                                            }
                                            var nameDiv = document.createElement("div");
                                            nameDiv.className = "mapname";
                                            nameDiv.appendChild(document.createTextNode(name));
                                            mapDiv.appendChild(nameDiv);
                                            var timeSlot = document.createElement("div");
                                            timeSlot.className = "startTime";
                                            var mapStartDate = null;
                                            var startTimeDate = toDate(dayStartTime);
                                            var dayStartDate = new Date(startTimeDate.getTime() + 10*60000);
                                            if (i == 1) {
                                                mapStartDate = dayStartDate;
                                            } else if (i > 1) {
                                                if (mapCount > 4 && i > 3) {
                                                    mapStartDate = new Date(dayStartDate.getTime() + (45*(i-1)+5)*60000);
                                                } else {
                                                    mapStartDate = new Date(dayStartDate.getTime() + 45*(i-1)*60000);
                                                }
                                            }
                                            var hours = mapStartDate.getHours();
                                            var minutes = (mapStartDate.getMinutes() < 10 ? '0' : '') + mapStartDate.getMinutes();
                                            mapStartTime = hours + ":" + minutes;
                                            timeSlot.appendChild(document.createTextNode(mapStartTime));
                                            mapDiv.appendChild(timeSlot);
                                        }
                                        maps.appendChild(mapDiv);
                                        i++;
                                    });
                                    return false;
                                });
                            } else {
                                console.log("League '"+group+"' not found");
                            }
                        });
                    });
                });

                $next = 1;
                $current = 0;
                $interval = 10000;
                $fadeTime = 800;
                $imgNum = $('.ad').length;
                function nextFadeIn() {

                    $('.sponsorbox img').eq($current).delay($interval).fadeOut($fadeTime).end().eq($next).delay($interval).hide().fadeIn($fadeTime, nextFadeIn);

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

                setInterval(function() {
                    $.getJSON('https://dev.kanaliiga.fi/gameday.json?rndstr='+new Date().getTime(), function(json) {
                        current = JSON.stringify(json);
                        if (origJson && current && origJson !== current) {
                            location.reload();
                        }
                    });
                }, 2000);

                var interval = setInterval(function() {
                    var mapStartMillis = null;
                    $.ajaxSetup({async:false});
                    $.getJSON('https://dev.kanaliiga.fi/starttimes.json?rndstr='+new Date().getTime(), function(startTimeJson) {
                        /*TOOD: Check if works for All-Stars*/
                        var tournamentJson = startTimeJson[tournament];
                        $.each(tournamentJson, function(index, value) {
                            $.each(value, function(key, startTime) {
                                if (key == group) {
                                    mapStartMillis = startTime;
                                    return false;
                                }
                                if (mapStartMillis != null) {
                                    return false;
                                }
                            });
                            if (mapStartMillis != null) {
                                return false;
                            }
                        });
                    });
                    var now = new Date().getTime();
                    var delta = mapStartMillis - now;

                    var minutes = Math.floor((delta % (1000 * 60 * 60)) / (1000 * 60));
                    var seconds = Math.floor((delta % (1000 * 60)) / 1000);

                    document.getElementById("counter").innerHTML = (minutes < 10 ? '0' : '') + minutes + ":" + (seconds < 10 ? '0' : '') + seconds;

                    if (delta < 0) {
                        document.getElementById("counter").innerHTML = "00:00";
                        if (Math.abs(delta) > 10*60*1000) {
                            document.getElementById("counterbox").style.display = "none";
                        } else {
                            document.getElementById("counterbox").style.display = "block";
                        }
                    } else {
                        document.getElementById("counterbox").style.display = "block";
                    }
                }, 1000);
            }
            function toDate(time) {
                var now = new Date();
                now.setHours(time.substr(0,time.indexOf(":")));
                now.setMinutes(time.substr(time.indexOf(":")+1));
                now.setSeconds(0);
                return now;
            }
        </script>
    </body>
</html>
