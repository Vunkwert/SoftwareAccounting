using System;
using System.Windows.Forms;

namespace SoftwareAccounting
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            bool keepRunning = true;

            while (keepRunning)
            {
                LoginForm loginForm = new LoginForm();
                Application.Run(loginForm);

                if (loginForm.IsAuthenticated)
                {
                    Form1 mainForm = new Form1(loginForm.UserRole, loginForm.LinkedComputerId);
                    Application.Run(mainForm);
                    keepRunning = mainForm.IsLogout;
                }
                else
                {
                    keepRunning = false;
                }
            }
        }
    }
}