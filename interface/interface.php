<?php
/////////////////////////////////////////////////////////
//                        SESSION                     //
/////////////////////////////////////////////////////////

session_start();
// Verif si user connecter si la variable $_SESSION comptien le username 
if(!isset($_SESSION["username"])){
    header("location: ./connection/formulaire_connection.php");
exit(); 
}

// déconnection
if(isset($_POST['deconnection'])){
    session_destroy();
    header('location: ./connection/formulaire_connection.php');
}

/////////////////////////////////////////////////////////
//                  RECUP DONNE CHART                  //
///////////////////////////////////////////////////////// 

include('./connection/connection_db.php');
$req = mysqli_query($conn, "SELECT temperature, humidite, historique FROM mesure ");

// Initialisation des tableaux
$temperature = [];
$humidite = [];
$historique = [];

// Boucle pour mettre les données dans les tableaux
while ($data = mysqli_fetch_assoc($req)) {
    $temperature[] = $data['temperature'];
    $humidite[] = $data["humidite"];
    $historique[] = $data["historique"];
}


?>

<!DOCTYPE html>
<html>
    <head>
        <title>Interface Iot</title>
        <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>

        <!-- ICON -->
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">

        <!-- CSS -->
        <link rel="stylesheet" href="./styles/interface.css">

        <!-- FONT -->
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=DotGothic16&display=swap" rel="stylesheet">

        <!-- CHART -->
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>  
    </head>

    <body>
        <!-- NAV BARRE -->
        <header>
            <div class="user" role="navigation" aria-label="Barre utilisateur">

                <?php
                    include('./connection/connection_db.php');
                    
                    // Assurez-vous que $_SESSION["username"] est protégé contre les injections SQL
                    $username = mysqli_real_escape_string($conn, $_SESSION["username"]);

                    $requete = "SELECT est_admin FROM identifiant WHERE username = '$username'";
                    $result = mysqli_query($conn, $requete);
                    $user_connect =$_SESSION["username"];
                    if ($result) {
                        $row = mysqli_fetch_assoc($result);
                        if ($row['est_admin'] == 1) {
                            echo "
                            <a class=\"user_connecter\" href='#'>
                                <i class=\"fa-solid fa-crown fa-bounce\" style=\"color: #FCDC12;\"></i>
                                <h1>$user_connect</h1>
                            </a> 
                            <ul>
                                <form  method='POST'>
                                    <button type='submit' name='deconnection' style=\"font-family: 'DotGothic16'; background-color: #212121; border:none; color:white; font-size: 18px;\">Deconnexion</button>
                                </form>
                                <a href='./avantage_admin/formulaire_inscription_admin.php'>ajout-admin</a>
                                <a href='./avantage_admin/vidange_donne_mesure.php'>vider-historique</a>
                                <a href='./avantage_admin/suppression_utilisateur.php'>sup-utilisateur</a>
                            </ul>
                            ";
                            
                        } else {
                            echo "
                            <a class=\"user_connecter\" href='#'>
                                <i class=\"fa-solid fa-user fa-beat-fade\" style=\"color: #74e01c;\"></i>
                                <h1>$user_connect</h1>
                            </a> 
                            <ul>
                                <form  method='POST'>
                                    <button type='submit' name='deconnection' style=\"font-family: 'DotGothic16'; background-color: #212121; border:none; color:white; font-size: 18px;\">Deconnexion</button>
                                </form>
                                <a href='https://raspberrypi2:8081'>Base de données</a>
                                <a href='http://raspberrypi2:8080'>Serveur LORAWAN</a>
                            </ul>
                            ";
                            
                        }
                    } else {
                        echo 'Erreur dans la requête SQL : ' . mysqli_error($conn);
                    }
                ?>




            </div>
        </header>

        <main>
            <!-- INTERFACE -->
            <div class="contenaire-interface">
                <section class="interface" aria-label="Données et graphique">
                    <section id="data" aria-live="polite">
                        <!-- Les données seront affichées ici -->
                    </section>
                    <section class="historique" aria-label="Graphique historique">
                        <div class="graphique">
                            <canvas id="graphique" aria-label="Graphique Température et Humidité" role="img"></canvas>
                        </div>
                    </section>
                </section>
            </div>
            <!-- ALERT -->
            <div id="contenenaire_error" aria-live="assertive"></div>
        </main>

        <!--***********************************************************
        **********        SCRIPT AJAX VALEUR TEMPS REEL          *******
        *************************************************************-->
        <script>
            /////////////////////////////////////////////////////////
            //                    POUR LES DONNEES                 //
            /////////////////////////////////////////////////////////
            $(document).ready(function() {
                function fetchData() {
                    $.ajax({
                        url: './../db/recuperation_donnee_mesure.php',
                        method: 'GET',
                        success: function(response) {
                            $('#data').html(response); // Mettre à jour le contenu de la zone de données
                        },
                        error: function(xhr, status, error) {
                            console.error('Erreur lors de la récupération des données:', error);
                        },
                        complete: function() {
                            // Répéter le processus toutes les 2 secondes
                            setTimeout(fetchData, 2000);
                        }
                    });
                }
                fetchData();
            });

            /////////////////////////////////////////////////////////
            //                     POUR LES CHART                  //
            ///////////////////////////////////////////////////////// 
            
            $(document).ready(function() {
                function fetchChartData() {
                    $.ajax({
                        url: './../db/recuperation_donnee_chart.php',
                        type: 'GET',
                        dataType: 'json',
                        success: function(data) {
                            // Mettre à jour les données du graphique avec les données reçues
                            myChart.data.labels = data.historique;
                            myChart.data.datasets[0].data = data.temperature;
                            myChart.data.datasets[1].data = data.humidite;
                            myChart.update(); // Mettre à jour le graphique
                        },
                        error: function(xhr, status, error) {
                            console.error('Erreur AJAX: ' + status, error);
                        }
                    });
                }
                setInterval(fetchChartData, 1000);
            });

            /////////////////////////////////////////////////////////
            //                     POUR LES ALERT                  //
            ///////////////////////////////////////////////////////// 
            
            $(document).ready(function() {
                function fetchData() {
                    $.ajax({
                        url: './../db/alert.php',
                        method: 'GET',
                        success: function(response) {
                            $('#contenenaire_error ').html(response); // Mettre à jour le contenu de la zone de données                            
                        },
                        error: function(xhr, status, error) {
                            console.error('Erreur lors de la récupération des données:', error);
                        },
                        complete: function() {
                            // Répéter le processus toutes les 2 secondes
                            setTimeout(fetchData, 20000);
                        }
                    });
                }
                fetchData(); 
            });
            

            /////////////////////////////////////////////////////////
            //              CHARTJS SCRIPT AFFICHAGE               //
            /////////////////////////////////////////////////////////

            Chart.defaults.borderColor = '#fff';
            Chart.defaults.color = '#ffff';
            Chart.defaults.font.size = 18;

            // Données pour le graphique
            const labels = <?php echo json_encode($historique) ?>;
            const temperature = <?php echo json_encode($temperature) ?>; // Température en degrés Celsius
            const humidite = <?php echo json_encode($humidite) ?>; // Humidité en pourcentage

            // Création du graphique
            const ctx = document.getElementById('graphique').getContext('2d');
            const myChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Température (°C)',
                        data: temperature,
                        borderColor: '#b0f2b6',
                        borderWidth: 2,
                        fill: false ,
                        backgroundColor: '#fff'
                    }, {
                        label: 'Humidité (%)',
                        data: humidite,
                        borderColor: 'rgb(54, 162, 235)',
                        borderWidth: 2,
                        fill: false,
                        backgroundColor: '#fff'
                    }]
                },
                options: {
                    scales: {
                        x: {
                            display: false
                        },
                        y: {
                            beginAtZero: true
                        }
                    },
                    plugins: {
                        legend: {
                            labels: {
                                font: {
                                    family: "'DotGothic16'"
                                }
                            }
                        }
                    }
                }
            });
        </script>
    </body>
</html>
