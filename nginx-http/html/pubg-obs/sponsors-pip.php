<html>
<head>
    <script src="https://code.jquery.com/jquery-3.2.1.min.js"></script>
    <title>Kanaliiga PUBG OBS Overlay: PiP sponsors</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@400;500&display=swap');
    body {
      overflow: hidden;
    }
    .scene {
      width: 1920px;
      height: 1080px;
    }
    .sponsorbox-map, .sponsorbox-blocks, .sponsorbox-diagonal {
        display: block !important;
    }
    .sponsorbox-map,.sponsorbox-blocks {
        width: 800px;
        height: 140px;
        display: flex;
        justify-content: center;
    }
    .sponsorbox-blocks {
      position: absolute;
      top: 920px;
      left: 40px;
    }
    .sponsorbox-diagonal {
      position: absolute;
      top: 840px;
      left: 10px;
      width: 625px;
      height: 140px;
      display: flex;
      justify-content: center;
    }
    .sponsorbox-map {
      position: absolute;
      top: 900px;
      left: 0px;
    }
    .sponsorbox-diagonal .grid-item img {
        max-width: 600px;
        max-height: 140px;
        height: auto;
        width: auto;
    }
    .sponsorbox-map .grid-item img,.sponsorbox-blocks .grid-item img {
        max-width: 750px;
        max-height: 140px;
        height: auto;
        width: auto;
    }
    #sponsorbox {
        display: none;
    }
    .grid-item {
        display: flex;
        justify-content: center;
    }
    img.ad {
        position: absolute;
    }
    h1 {
        font-family: 'Big Shoulders Display', sans-serif;
        text-transform: uppercase;
        color: #2a292a;
        font-size: 40px;
        text-align: center;
        margin-block-start: 2px;
    }
    h2 {
        font-family: 'Big Shoulders Display', sans-serif;
        text-transform: uppercase;
        color: #f29209;
        font-size: 40px;
        text-align: center;
        margin-block-start: 0.2em;
        margin-block-end: 0.2em;
    }
    .h1box {
        position: absolute;
        top: 0px;
        left: 0px;
        width: 350px;
        height: 54px;
        background: rgba(242, 146, 9, 0.90);
        margin-top: 4px;
        margin-left: 4px;
    }
    .h2box {
        position: absolute;
        top: 58px;
        left: 0px;
        width: 350px;
        margin-left: 4px;
    }
    .mapinfo {
        position: absolute;
        top: 106px;
        left: 0px;
        width: 350px;
        margin-left: 4px;
    }
    .headline-map, .headline-blocks, .headline-diagonal {
        display: block !important;
    }
    .headline-map {
        position: absolute;
        top: 80px;
        left: 210px;
    }
    .headline-blocks {
        position: absolute;
        top: 100px;
        left: 1530px;
    }
    .headline-diagonal {
        position: absolute;
        top: 80px;
        left: 1485px;
    }
    #headline {
        width: 350px;
        height: 135px;
        display: none;
    }
    .logo {
        position: absolute;
        left: -130px;
        height: 135px;
        width: auto;
    }
  </style>
</head>
<body onload="createPage()">
  <div class="scene">
      <div id="headline">
          <img class="logo" src="./img/kanaliiga-logo-yellow.png" />
          <div id="h1box" class="h1box">
          </div>
          <div id="h2box" class="h2box">
          </div>
          <div id="mapinfo" class="mapinfo">
          </div>
      </div>
    <div id="sponsorbox">
      <div class="carousel">
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
  </div>
  <script>
      function createPage() {
          var queryString = window.location.search;
          var urlParams = new URLSearchParams(queryString);
          var group = urlParams.get('league');
          var origJson = null;
          var scene = urlParams.get('scene');
          $.get('https://dev.kanaliiga.fi/tournament.txt', function(tournament) {
              var randomStr = new Date().getTime();
              $.getJSON('https://dev.kanaliiga.fi/gameday.json?rndstr='+randomStr, function(json) {
                  origJson = JSON.stringify(json);
                  var h1box = document.getElementById("h1box");
                  var h2box = document.getElementById("h2box");
                  var h3box = document.getElementById("mapinfo");
                  var tournamenth1 = document.createElement("h1");
                  var tournamenth2 = document.createElement("h2");
                  var mapinfo = document.createElement("h2");
                  var tournamentName = json.name.toLowerCase().replace("kanaliiga ", "");
                  $(json.gameDays).each(function(index, groupJson) {
                      if (!group || groupJson.key == group) {
                          if (!group) {
                              group = groupJson.key;
                          }
                          var currentDayPlayedMaps = groupJson.currentDayPlayedMaps + 1;
                          var currentMatchDay = groupJson.currentMatchDay;
                          var dayCount = groupJson.allMatchDates.length;
                          var mapcount = groupJson.maps.length;
                          var league = groupJson.league;
                          if (tournamentName.toLowerCase().endsWith("qualifiers") && league.toLowerCase().endsWith("qualifiers")) {
                              league = league.toLowerCase().replace("qualifiers", "");
                          }
                          tournamenth1.appendChild(document.createTextNode(tournamentName));
                          tournamenth2.appendChild(document.createTextNode(league));
                          mapinfo.appendChild(document.createTextNode(" DAY "+currentMatchDay+" MAP "+currentDayPlayedMaps));
                          h1box.appendChild(tournamenth1);
                          h2box.appendChild(tournamenth2);
                          h3box.appendChild(mapinfo);
                          return false;
                      } else {
                          console.log("League '"+group+"' not found");
                      }
                  });
              });
          });

          var sponsorbox = document.getElementById("sponsorbox");
          var headline = document.getElementById("headline");
          if (scene == "diagonal") {
              sponsorbox.className = "sponsorbox-diagonal";
              headline.className = "headline-diagonal"
          } else if (scene == "blocks") {
              sponsorbox.className = "sponsorbox-blocks";
              headline.className = "headline-blocks"
          } else if (scene == "map") {
              sponsorbox.className = "sponsorbox-map";
              headline.className = "headline-map"
          }

          $next = 1;
          $current = 0;
          $interval = 5000;
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
          }, 60000);
      }
  </script>
</body>
</html>
