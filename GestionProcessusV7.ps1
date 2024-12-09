# ** Configurer l'encodage UTF-8 pour PowerShell **
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ** Fichier pour enregistrer les processus arrêtés **
$logFile = "processus_arretes.log"

# ** Liste des processus critiques à protéger **
$ProcessusCritiques = @("svchost", "winlogon", "lsass", "explorer", "csrss")

# ** Fonction pour enregistrer dans le log **
function Enregistrer-DansLog {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp, $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# ** Fonction pour lister les processus avec des couleurs **
function Afficher-Processus {
    Write-Host "Liste des processus en cours d'exécution :" -ForegroundColor Magenta

    # ** Récupérer la liste des processus **
    $processes = Get-Process | Select-Object Id, ProcessName, CPU, Path

    # ** Trier les processus : ceux sans chemin en premier, puis ceux avec un chemin **
    $sortedProcesses = $processes | Sort-Object { if ([string]::IsNullOrEmpty($_.Path)) { 0 } else { 1 } }, ProcessName

    # ** Afficher les processus triés **
    foreach ($process in $sortedProcesses) {
        if ($ProcessusCritiques -contains $process.ProcessName) {
            Write-Host "ID:" -ForegroundColor Red -NoNewline
            Write-Host " $($process.Id) " -ForegroundColor Red -NoNewline
            Write-Host "| Nom:" -ForegroundColor Red -NoNewline
            Write-Host " $($process.ProcessName) " -ForegroundColor Red -NoNewline
            Write-Host "| CPU:" -ForegroundColor Red -NoNewline
            Write-Host " $($process.CPU) " -ForegroundColor Red -NoNewline
            Write-Host "| Chemin:" -ForegroundColor Red -NoNewline
            Write-Host " $($process.Path)" -ForegroundColor Red
        } else {
            Write-Host "ID:" -ForegroundColor Cyan -NoNewline
            Write-Host " $($process.Id) " -ForegroundColor Yellow -NoNewline
            Write-Host "| Nom:" -ForegroundColor Cyan -NoNewline
            Write-Host " $($process.ProcessName) " -ForegroundColor Yellow -NoNewline
            Write-Host "| CPU:" -ForegroundColor Cyan -NoNewline
            Write-Host " $($process.CPU) " -ForegroundColor Green -NoNewline
            Write-Host "| Chemin:" -ForegroundColor Cyan -NoNewline
            Write-Host " $($process.Path)" -ForegroundColor Green
        }
    }
}


# ** Fonction pour confirmer une action **
function Demander-Confirmation {
    param (
        [string]$Message
    )
    $reponse = Read-Host "$Message (Oui/Non)"
    return $reponse -match "^(O|o|Oui|oui|Y|y|Yes|yes)$"
}

# ** Fonction pour arrêter un processus par ID **
function Terminer-ProcessusParID {
    param (
        [int]$ProcessId
    )
    try {
        # ?? Obtenir les informations du processus avant de l'arrêter ??
        $processInfo = Get-Process -Id $ProcessId -ErrorAction Stop | Select-Object Id, ProcessName, Path
        
        # ?? Vérifier si le processus est critique ??      
        if ($ProcessusCritiques -contains $processInfo.ProcessName) {
            Write-Host "Le processus $($processInfo.ProcessName) est critique et ne peut pas être arrêté." -ForegroundColor Red
            Enregistrer-DansLog "Tentative d'arrêt bloquée pour le processus critique $($processInfo.ProcessName)."
            return
        }

        # ?? Demander confirmation ??
        if (-not (Demander-Confirmation "Êtes-vous sûr de vouloir arrêter le processus $($processInfo.ProcessName) (ID=$ProcessId) ?")) {
            Write-Host "Action annulée par l'utilisateur." -ForegroundColor Cyan
            return
        }

        # ?? Enregistrer dans le fichier log ??
        Enregistrer-DansLog "Arrêt du processus : ID=$($processInfo.Id), Nom=$($processInfo.ProcessName), Chemin=$($processInfo.Path)"
        
        # ?? Arrêter le processus ??
        Stop-Process -Id $ProcessId -Force
        Write-Host "Processus avec l'ID $ProcessId arrêté avec succès." -ForegroundColor Green
    } catch {
        Write-Host "Impossible d'arrêter le processus. Vérifiez l'ID." -ForegroundColor Red
        Enregistrer-DansLog "Erreur lors de l'arrêt du processus avec ID=$ProcessId. Erreur : $_"
    }
}

# ** Fonction pour arrêter un processus par nom **
function Terminer-ProcessusParNom {
    param (
        [string]$ProcessName
    )
    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction Stop | Select-Object Id, ProcessName, Path
        
        if ($ProcessusCritiques -contains $processes.ProcessName) {
            Write-Host "Le processus $($processes.ProcessName) est critique et ne peut pas être arrêté." -ForegroundColor Red
            Enregistrer-DansLog "Tentative d'arrêt bloquée pour le processus critique $($processes.ProcessName)."
            return
        }

        if (-not (Demander-Confirmation "Êtes-vous sûr de vouloir arrêter le processus $($processes.ProcessName) ?")) {
            Write-Host "Action annulée par l'utilisateur." -ForegroundColor Cyan
            return
        }

        foreach ($proc in $processes) {
            Enregistrer-DansLog "Arrêt du processus : ID=$($proc.Id), Nom=$($proc.ProcessName), Chemin=$($proc.Path)"
        }

        Get-Process -Name $ProcessName | Stop-Process -Force
        Write-Host "Processus avec le nom $ProcessName arrêté avec succès." -ForegroundColor Green
    } catch {
        Write-Host "Impossible d'arrêter le processus. Vérifiez le nom." -ForegroundColor Red
        Enregistrer-DansLog "Erreur lors de l'arrêt du processus nommé $ProcessName. Erreur : $_"
    }
}

# ** Fonction pour relancer un processus **
function Relancer-ProcessusParNom {
    param (
        [string]$ProcessName
    )
    try {
        Start-Process $ProcessName
        Write-Host "Processus $ProcessName relancé avec succès." -ForegroundColor Green
        Enregistrer-DansLog "Relance du processus : Nom=$ProcessName"
    } catch {
        Write-Host "Erreur : Impossible de relancer le processus $ProcessName. Vérifiez qu'il existe." -ForegroundColor Red
        Enregistrer-DansLog "Erreur lors de la relance du processus nommé $ProcessName. Erreur : $_"
    }
}

# ** Fonction pour afficher les processus arrêtés récemment **
function Afficher-ProcessusArretes {
    if (Test-Path $logFile) {
        Write-Host "Liste des processus récemment arrêtés ou relancés :" -ForegroundColor Cyan
        Write-Host "----------------------------------------------------" -ForegroundColor Cyan
        Write-Host "Date/Heure            | ID       | Nom             | Chemin" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------" -ForegroundColor Cyan
        
        Get-Content $logFile | Where-Object {
            $_ -match "Arrêt du processus :"
        } | ForEach-Object {
            # ** Analyse des données de chaque ligne du fichier log **
            $data = $_ -split ","
            $dateHeure = $data[0]
            $id = $data[1] -replace ".*ID=", ""
            $nom = $data[2] -replace ".*Nom=", ""
            $chemin = $data[3] -replace ".*Chemin=", ""

            # ** Affichage coloré des données **
            Write-Host "$dateHeure" -ForegroundColor Green -NoNewline
            Write-Host " | " -NoNewline
            Write-Host "$id" -ForegroundColor Cyan -NoNewline
            Write-Host " | " -NoNewline
            Write-Host "$nom" -ForegroundColor Magenta -NoNewline
            Write-Host " | " -NoNewline
            Write-Host "$chemin" -ForegroundColor White
        }
    } else {
        Write-Host "Aucun processus arrêté n'a été enregistré." -ForegroundColor Yellow
    }
}


# ** Menu principal **
function Main-Menu {
    while ($true) {
        Write-Host "`n=== Menu Principal ===" -ForegroundColor Yellow
        Write-Host "1. Lister les processus"
        Write-Host "2. Arrêter un processus par ID"
        Write-Host "3. Arrêter un processus par nom"
        Write-Host "4. Relancer un processus par nom"
        Write-Host "5. Afficher les processus récemment arrêtés"
        Write-Host "6. Quitter"

        $choice = Read-Host "Choisissez une option"

        switch ($choice) {
            1 {
                Afficher-Processus
            }
            2 {
                $id = Read-Host "Entrez l'ID du processus à arrêter"
                if ($id -as [int]) {
                    Terminer-ProcessusParID -ProcessId $id
                } else {
                    Write-Host "Entrée invalide : l'ID doit être un entier." -ForegroundColor Red
                }
            }
            3 {
                $processName = Read-Host "Entrez le nom du processus à arrêter"
                if (-not [string]::IsNullOrWhiteSpace($processName)) {
                    Terminer-ProcessusParNom -ProcessName $processName
                } else {
                    Write-Host "Le nom du processus ne peut pas être vide." -ForegroundColor Red
                }
            }
            4 {
                $name = Read-Host "Entrez le nom du processus à relancer"
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    Relancer-ProcessusParNom -ProcessName $name
                } else {
                    Write-Host "Le nom du processus ne peut pas être vide." -ForegroundColor Red
                }
            }
            5 {
                Afficher-ProcessusArretes
            }
            6 {
                Write-Host "Au revoir !" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "Option invalide, veuillez réessayer." -ForegroundColor Red
            }
        }
    }
}

# ** Lancer le programme **

Write-Host "Bienvenue dans le programme de gestion des processus!" -ForegroundColor Green
Write-Host "Utilisez les options du menu pour effectuer des actions." -ForegroundColor Green
Main-Menu
