using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace ClaudeScreen
{
    // Windows calls: DPI, screen capture, mouse, keyboard.
    public static class Natif
    {
        [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr valeur);
        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
        [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
        [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
        [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] entrees, int taille);
        [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder texte, int max);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, string l);
        [DllImport("winmm.dll")] static extern uint timeBeginPeriod(uint ms);
        [DllImport("winmm.dll")] static extern uint timeEndPeriod(uint ms);

        // Smooth mode (icon menu, data\smooth.txt): human-like mouse moves and typing. Set by actions.ps1.
        public static bool Doux = false;
        static readonly Random Hasard = new Random();

        public static IntPtr PremierPlan() { return GetForegroundWindow(); }

        public static void MettreAuPremierPlan(IntPtr h) { SetForegroundWindow(h); }

        // Grey placeholder text shown in an empty field.
        public static void Indice(IntPtr champ, string texte) { SendMessage(champ, 0x1501, new IntPtr(1), texte); }

        [StructLayout(LayoutKind.Sequential)] struct POINT { public int X; public int Y; }
        [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }
        [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
        [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
        [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

        const uint SOURIS = 0, CLAVIER = 1;
        const uint GAUCHE_BAS = 0x2, GAUCHE_HAUT = 0x4, DROIT_BAS = 0x8, DROIT_HAUT = 0x10, MOLETTE = 0x800;
        const uint TOUCHE_ETENDUE = 0x1, TOUCHE_HAUT = 0x2, UNICODE = 0x4;

        public static void DpiAware()
        {
            try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; } catch { }
            try { SetProcessDPIAware(); } catch { }
        }

        // Foreground window: { process name, title }.
        public static string[] FenetreActive()
        {
            IntPtr h = GetForegroundWindow();
            System.Text.StringBuilder titre = new System.Text.StringBuilder(512);
            GetWindowText(h, titre, titre.Capacity);
            string nom = "";
            try
            {
                uint pid;
                GetWindowThreadProcessId(h, out pid);
                nom = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName;
            }
            catch { }
            return new string[] { nom, titre.ToString() };
        }

        // Screen (physical coordinates) under the cursor.
        public static Rectangle EcranSousCurseur()
        {
            POINT p;
            GetCursorPos(out p);
            return Screen.FromPoint(new Point(p.X, p.Y)).Bounds;
        }

        // Captures the rectangle and saves it scaled down by a factor "echelle" (>= 1).
        public static void Capture(string chemin, int gauche, int haut, int largeur, int hauteur, double echelle)
        {
            using (Bitmap brut = new Bitmap(largeur, hauteur, PixelFormat.Format32bppArgb))
            {
                using (Graphics g = Graphics.FromImage(brut))
                    g.CopyFromScreen(gauche, haut, 0, 0, new Size(largeur, hauteur));
                int l = Math.Max(1, (int)Math.Round(largeur / echelle));
                int h = Math.Max(1, (int)Math.Round(hauteur / echelle));
                using (Bitmap petit = new Bitmap(l, h, PixelFormat.Format24bppRgb))
                {
                    using (Graphics g = Graphics.FromImage(petit))
                    {
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.DrawImage(brut, 0, 0, l, h);
                    }
                    petit.Save(chemin, ImageFormat.Png);
                }
            }
        }

        static INPUT Souris(uint drapeaux, uint donnees)
        {
            INPUT e = new INPUT();
            e.type = SOURIS;
            e.u.mi.dwFlags = drapeaux;
            e.u.mi.mouseData = donnees;
            return e;
        }

        static INPUT Touche(ushort vk, ushort scan, uint drapeaux)
        {
            INPUT e = new INPUT();
            e.type = CLAVIER;
            e.u.ki.wVk = vk;
            e.u.ki.wScan = scan;
            e.u.ki.dwFlags = drapeaux;
            return e;
        }

        static void Envoyer(params INPUT[] entrees)
        {
            SendInput((uint)entrees.Length, entrees, Marshal.SizeOf(typeof(INPUT)));
        }

        static double Entre(double a, double b) { return a + Hasard.NextDouble() * (b - a); }

        static void Pause(double secondes) { Thread.Sleep((int)Math.Round(secondes * 1000)); }

        // Smooth mode: moves the mouse like a hand. Curved path (cubic Bezier bent a little to one side),
        // speeds up then slows down (minimum-jerk profile), duration that grows with the distance
        // (Fitts' law): ~0.2 s for a short hop, ~0.75 s across a large screen.
        // lenteur > 1 slows down (dragging); courbe < 1 makes the path straighter.
        static void Trajet(int x1, int y1, double lenteur, double courbe)
        {
            POINT p;
            GetCursorPos(out p);
            double x0 = p.X, y0 = p.Y, dx = x1 - x0, dy = y1 - y0;
            double d = Math.Sqrt(dx * dx + dy * dy);
            if (d < 3) { SetCursorPos(x1, y1); return; }
            double duree = Math.Min(1.1, Math.Max(0.18, 0.12 + 0.11 * Math.Log(1 + d / 20.0, 2))) * Entre(0.9, 1.1) * lenteur;
            double nx = -dy / d, ny = dx / d;   // unit vector perpendicular to the line
            double ecart = Math.Min(120.0, d * Entre(0.05, 0.18)) * courbe * (Hasard.Next(2) == 0 ? -1 : 1);
            double a = Entre(0.2, 0.35), b = Entre(0.65, 0.8), f1 = Entre(0.6, 1.0), f2 = Entre(0.3, 0.7);
            double c1x = x0 + dx * a + nx * ecart * f1, c1y = y0 + dy * a + ny * ecart * f1;
            double c2x = x0 + dx * b + nx * ecart * f2, c2y = y0 + dy * b + ny * ecart * f2;
            timeBeginPeriod(1);   // 1 ms timer: otherwise Sleep waits ~15 ms and the movement stutters
            try
            {
                // The position comes from the elapsed time: a busy PC skips points instead of slowing down.
                Stopwatch chrono = Stopwatch.StartNew();
                while (true)
                {
                    double t = chrono.Elapsed.TotalSeconds / duree;
                    if (t >= 1) break;
                    double s = t * t * t * (10 - 15 * t + 6 * t * t), u = 1 - s;
                    double x = u * u * u * x0 + 3 * u * u * s * c1x + 3 * u * s * s * c2x + s * s * s * x1;
                    double y = u * u * u * y0 + 3 * u * u * s * c1y + 3 * u * s * s * c2y + s * s * s * y1;
                    SetCursorPos((int)Math.Round(x), (int)Math.Round(y));
                    Thread.Sleep(8);
                }
            }
            finally { timeEndPeriod(1); }
            SetCursorPos(x1, y1);
        }

        public static void Deplacer(int x, int y)
        {
            if (Doux) { Trajet(x, y, 1.0, 1.0); Pause(Entre(0.06, 0.14)); }   // short pause before clicking
            else { SetCursorPos(x, y); Thread.Sleep(30); }
        }

        public static void Clic(int x, int y, bool droit, int nombre)
        {
            Deplacer(x, y);
            for (int i = 0; i < nombre; i++)
            {
                if (droit) Envoyer(Souris(DROIT_BAS, 0), Souris(DROIT_HAUT, 0));
                else Envoyer(Souris(GAUCHE_BAS, 0), Souris(GAUCHE_HAUT, 0));
                Thread.Sleep(Doux ? (int)Entre(70, 110) : 60);
            }
        }

        public static void Glisser(int x1, int y1, int x2, int y2)
        {
            Deplacer(x1, y1);
            Envoyer(Souris(GAUCHE_BAS, 0));
            if (Doux)
            {
                // Press, wait a little, drag slowly in an almost straight line, wait, release.
                Pause(Entre(0.08, 0.14));
                Trajet(x2, y2, 1.4, 0.4);
                Pause(Entre(0.08, 0.14));
            }
            else
            {
                for (int i = 1; i <= 20; i++)
                {
                    SetCursorPos(x1 + (x2 - x1) * i / 20, y1 + (y2 - y1) * i / 20);
                    Thread.Sleep(15);
                }
            }
            Envoyer(Souris(GAUCHE_HAUT, 0));
        }

        public static void Molette(int x, int y, int crans)
        {
            Deplacer(x, y);
            if (!Doux) { Envoyer(Souris(MOLETTE, unchecked((uint)(crans * 120)))); return; }
            // One notch at a time, like a finger on the wheel.
            int sens = crans > 0 ? 1 : -1;
            for (int i = 0; i < Math.Abs(crans); i++)
            {
                if (i > 0) Pause(Entre(0.07, 0.13));
                Envoyer(Souris(MOLETTE, unchecked((uint)(sens * 120))));
            }
        }

        static bool Etendue(ushort vk)
        {
            return (vk >= 0x21 && vk <= 0x28) || vk == 0x2D || vk == 0x2E || vk == 0x5B || vk == 0x5C;
        }

        // Presses the keys in order, then releases them in reverse order.
        public static void Combo(ushort[] vks)
        {
            foreach (ushort vk in vks) { Envoyer(Touche(vk, 0, Etendue(vk) ? TOUCHE_ETENDUE : 0)); Thread.Sleep(20); }
            for (int i = vks.Length - 1; i >= 0; i--) { Envoyer(Touche(vks[i], 0, TOUCHE_HAUT | (Etendue(vks[i]) ? TOUCHE_ETENDUE : 0))); Thread.Sleep(20); }
        }

        // Smooth mode: pause after each character. ~9 characters per second with irregular gaps,
        // longer after a space, punctuation and Enter (which also gives a terminal time to answer).
        // Long texts are typed faster so that one action never takes more than ~45 s
        // (Claude Code stops a command after 2 minutes).
        static double[] DelaisFrappe(string texte)
        {
            double[] delais = new double[texte.Length];
            double total = 0;
            for (int i = 0; i < texte.Length; i++)
            {
                char c = texte[i];
                if (c == '\r') continue;
                double d = Entre(0.07, 0.15);
                if (char.IsUpper(c)) d += 0.03;                       // Shift
                if (c == ' ') d += Entre(0.02, 0.08);                 // between two words
                else if (".,;:!?".IndexOf(c) >= 0) d += Entre(0.12, 0.25);   // end of a phrase
                else if (c == '\n') d += Entre(0.25, 0.45);           // Enter
                delais[i] = d;
                total += d;
            }
            if (total > 45)
                for (int i = 0; i < delais.Length; i++)
                    if (delais[i] > 0) delais[i] = Math.Max(0.012, delais[i] * 45 / total);
            return delais;
        }

        public static void Taper(string texte)
        {
            double[] delais = Doux ? DelaisFrappe(texte) : null;
            if (Doux) timeBeginPeriod(1);
            try
            {
                for (int i = 0; i < texte.Length; i++)
                {
                    char c = texte[i];
                    if (c == '\r') continue;
                    if (c == '\n') Combo(new ushort[] { 0x0D });
                    else if (c == '\t') Combo(new ushort[] { 0x09 });
                    else Envoyer(Touche(0, c, UNICODE), Touche(0, c, UNICODE | TOUCHE_HAUT));
                    if (Doux) Pause(delais[i]); else Thread.Sleep(8);
                }
            }
            finally { if (Doux) timeEndPeriod(1); }
        }
    }

    // Invisible window that receives the global hotkeys.
    public class Raccourcis : NativeWindow
    {
        [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mods, uint vk);
        [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);

        public Action<int> SurAppui;

        public Raccourcis() { CreateHandle(new CreateParams()); }

        public bool Enregistrer(int id, uint mods, uint vk) { return RegisterHotKey(Handle, id, mods | 0x4000, vk); }

        public void Liberer(int id) { UnregisterHotKey(Handle, id); }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x0312 && SurAppui != null) SurAppui(m.WParam.ToInt32());
            base.WndProc(ref m);
        }
    }
}
