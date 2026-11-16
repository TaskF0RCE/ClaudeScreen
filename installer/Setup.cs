// ClaudeScreen-Setup.exe: copies the app into %USERPROFILE%\ClaudeScreen, makes it start with Windows
// and starts it. The files of the app are inside this program (app.zip, added by Build-Setup.ps1).
// It only writes in the chosen folder and never deletes anything: data\ (your settings, the tasks) and
// your Documents\Claude-Work folder are left as they are, so running a newer Setup updates the app.
//
//   ClaudeScreen-Setup.exe            asks, installs, starts the app
//   /S          no question and no message (exit code: 0 done, 1 cancelled, 2 refused, 3 error)
//   /D=FOLDER   install there instead of %USERPROFILE%\ClaudeScreen
//   /NoStart    copy the files only: no scheduled task, the app is not started (used by the tests)
//
// Plain C# 5 for the compiler that ships with Windows (csc.exe of .NET Framework 4).
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

static class Setup
{
    const string Nom = "ClaudeScreen";

    [STAThread]
    static int Main(string[] args)
    {
        bool silencieux = false, sansDemarrage = false;
        string cible = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), Nom);
        foreach (string a in args)
        {
            if (a.Equals("/S", StringComparison.OrdinalIgnoreCase)) silencieux = true;
            else if (a.Equals("/NoStart", StringComparison.OrdinalIgnoreCase)) sansDemarrage = true;
            else if (a.StartsWith("/D=", StringComparison.OrdinalIgnoreCase)) cible = Path.GetFullPath(a.Substring(3).Trim('"'));
        }
        string version = Assembly.GetExecutingAssembly().GetName().Version.ToString(3);
        string titre = Nom + " " + version;
        Application.EnableVisualStyles();
        Form attente = null;
        try
        {
            if (Directory.Exists(Path.Combine(cible, ".git")))
            {
                // A copy made with git: its owner updates it with git, and this Setup would leave it half changed.
                if (!silencieux) MessageBox.Show(cible + " is a git copy of the project.\n\nUpdate it with: git pull", titre, MessageBoxButtons.OK, MessageBoxIcon.Information);
                return 2;
            }
            bool dejaLa = File.Exists(Path.Combine(cible, "ClaudeScreen.ps1"));
            if (!silencieux)
            {
                string question = (dejaLa ? "Update ClaudeScreen to version " + version + " in:\n" : "Install ClaudeScreen " + version + " in:\n") + cible + "\n\n"
                    + "It will start with Windows (scheduled task \"ClaudeScreen\") and show an icon in the notification area."
                    + (dejaLa ? "\nYour settings, your tasks and your Claude-Work folder are kept." : "");
                if (MessageBox.Show(question, titre, MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return 1;
                attente = Attente(titre);
            }
            Extraire(cible);
            if (!sansDemarrage) Demarrer(cible);
            if (attente != null) { attente.Close(); attente = null; }
            if (!silencieux)
            {
                string fin = "ClaudeScreen " + version + " is installed.\n\n";
                if (ClaudeTrouve()) fin += "Its icon is in the notification area (near the clock). Put a task on screen and press Ctrl+Alt+C.";
                else fin += "One thing is missing: Claude Code, which ClaudeScreen runs on.\n\n"
                    + "1. Open PowerShell and run:\n     irm https://claude.ai/install.ps1 | iex\n"
                    + "2. Run claude once and log in with your Claude account, then type /exit.\n\n"
                    + "Then put a task on screen and press Ctrl+Alt+C.";
                MessageBox.Show(fin, titre, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            return 0;
        }
        catch (Exception ex)
        {
            if (attente != null) attente.Close();
            if (!silencieux) MessageBox.Show("The installation did not finish:\n\n" + ex.Message, titre, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 3;
        }
    }

    // A small window while the files are copied and the app is started (the PDF tool is downloaded then, about 16 MB).
    static Form Attente(string titre)
    {
        Form f = new Form();
        f.Text = titre; f.FormBorderStyle = FormBorderStyle.FixedDialog; f.ControlBox = false;
        f.StartPosition = FormStartPosition.CenterScreen; f.ClientSize = new Size(360, 70); f.TopMost = true;
        Label l = new Label();
        l.Text = "Installing ClaudeScreen... (up to a minute)"; l.Dock = DockStyle.Fill; l.TextAlign = ContentAlignment.MiddleCenter;
        f.Controls.Add(l);
        f.Show();
        Application.DoEvents();
        return f;
    }

    // Copies the files of the app over the folder. Nothing outside it, nothing deleted.
    static void Extraire(string cible)
    {
        string racine = Path.GetFullPath(cible).TrimEnd('\\') + "\\";
        Directory.CreateDirectory(racine);
        using (Stream flux = Assembly.GetExecutingAssembly().GetManifestResourceStream("app.zip"))
        {
            if (flux == null) throw new InvalidOperationException("This Setup holds no files (app.zip is missing).");
            using (ZipArchive zip = new ZipArchive(flux, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entree in zip.Entries)
                {
                    string relatif = entree.FullName.Replace('/', '\\');
                    if (relatif.EndsWith("\\") || relatif.Length == 0) continue;
                    string chemin = Path.GetFullPath(Path.Combine(racine, relatif));
                    if (!chemin.StartsWith(racine, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Unexpected path in the Setup: " + entree.FullName);
                    Directory.CreateDirectory(Path.GetDirectoryName(chemin));
                    entree.ExtractToFile(chemin, true);
                    Application.DoEvents();
                }
            }
        }
    }

    // Closes the copy of the app that runs from this folder (an update), installs the scheduled task, starts the app.
    static void Demarrer(string cible)
    {
        string dossier = cible.TrimEnd('\\').Replace("'", "''");
        string commande = "$ErrorActionPreference = 'Stop'; $s = '" + dossier + "\\ClaudeScreen.ps1'; "
            + "Get-CimInstance Win32_Process -Filter \\\"Name = 'powershell.exe'\\\" | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($s, [StringComparison]::OrdinalIgnoreCase) -ge 0 } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; "
            + "& '" + dossier + "\\Installer-Demarrage.ps1' | Out-Null; Start-ScheduledTask -TaskName ClaudeScreen";
        ProcessStartInfo psi = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -Command \"" + commande + "\"");
        psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.RedirectStandardError = true;
        using (Process p = Process.Start(psi))
        {
            string erreurs = p.StandardError.ReadToEnd();
            if (!p.WaitForExit(300000)) { try { p.Kill(); } catch { } throw new InvalidOperationException("Starting the app took more than 5 minutes."); }
            if (p.ExitCode != 0) throw new InvalidOperationException("The files are in " + cible + ", but the app could not be started:\n" + erreurs.Trim());
        }
    }

    // Where the app itself looks for Claude Code.
    static bool ClaudeTrouve()
    {
        string profil = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (File.Exists(Path.Combine(profil, ".local\\bin\\claude.exe"))) return true;
        if (File.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "npm\\claude.cmd"))) return true;
        foreach (string dossier in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';'))
        {
            if (dossier.Trim().Length == 0) continue;
            foreach (string nom in new string[] { "claude.exe", "claude.cmd", "claude.bat" })
            {
                try { if (File.Exists(Path.Combine(dossier.Trim(), nom))) return true; } catch { }
            }
        }
        return false;
    }
}
