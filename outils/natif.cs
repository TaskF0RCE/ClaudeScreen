using System;
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

        public static void Deplacer(int x, int y) { SetCursorPos(x, y); Thread.Sleep(30); }

        public static void Clic(int x, int y, bool droit, int nombre)
        {
            Deplacer(x, y);
            for (int i = 0; i < nombre; i++)
            {
                if (droit) Envoyer(Souris(DROIT_BAS, 0), Souris(DROIT_HAUT, 0));
                else Envoyer(Souris(GAUCHE_BAS, 0), Souris(GAUCHE_HAUT, 0));
                Thread.Sleep(60);
            }
        }

        public static void Glisser(int x1, int y1, int x2, int y2)
        {
            Deplacer(x1, y1);
            Envoyer(Souris(GAUCHE_BAS, 0));
            for (int i = 1; i <= 20; i++)
            {
                SetCursorPos(x1 + (x2 - x1) * i / 20, y1 + (y2 - y1) * i / 20);
                Thread.Sleep(15);
            }
            Envoyer(Souris(GAUCHE_HAUT, 0));
        }

        public static void Molette(int x, int y, int crans)
        {
            Deplacer(x, y);
            Envoyer(Souris(MOLETTE, unchecked((uint)(crans * 120))));
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

        public static void Taper(string texte)
        {
            foreach (char c in texte)
            {
                if (c == '\r') continue;
                if (c == '\n') Combo(new ushort[] { 0x0D });
                else if (c == '\t') Combo(new ushort[] { 0x09 });
                else Envoyer(Touche(0, c, UNICODE), Touche(0, c, UNICODE | TOUCHE_HAUT));
                Thread.Sleep(8);
            }
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
