<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>Kanaliiga PUBG OBS Graphics - Caster title</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@700;800&display=swap');

        body {
            font-family: "Big Shoulders Display";
            font-weight: 800;
            color: #FFFFFF;
            overflow: hidden;
            text-transform: capitalize;
            font-size: 40px;
        }
        .nick {
            text-transform: uppercase;
            font-size: 45px;
        }
        .scene {
            width: 1920px;
            height: 1080px;
        }

        .caster {
            position: absolute;
            top: 850px;
            left: 50px;
            width: 880px;
            text-align: center;
        }

        .cocaster {
            position: absolute;
            top: 850px;
            left: 990px;
            width: 880px;
            text-align: center;
        }

        .solocaster {
            position: absolute;
            top: 850px;
            left: 520px;
            width: 880px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="scene">
        <?php
            $position = htmlspecialchars($_GET["position"]);
            $firstname = htmlspecialchars($_GET["firstname"]);
            $nick = htmlspecialchars($_GET["nick"]);
            $lastname = htmlspecialchars($_GET["lastname"]);

            if (! empty($nick)) {
                $nick = "\"".$nick."\" ";
            }
            echo "<div class=\"".$position."\">";
            echo $firstname." <span class=\"nick\">".$nick."</span>".$lastname;
            echo "</div>";
        ?>
    </div>
</body>
</html>
