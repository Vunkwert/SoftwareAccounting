using Npgsql;
using System;
using System.Windows.Forms;

namespace SoftwareAccounting
{
    public partial class LoginForm : Form
    {
        DbHelper db = new DbHelper();

        // Свойства для передачи данных в главную форму
        public string UserRole { get; private set; }
        public int? LinkedComputerId { get; private set; }
        public bool IsAuthenticated { get; private set; } = false;

        public LoginForm()
        {
            InitializeComponent();
        }

        private void btnLogin_Click(object sender, EventArgs e)
        {
            string login = txtLogin.Text.Trim();
            string pass = txtPassword.Text.Trim();

            if (string.IsNullOrEmpty(login) || string.IsNullOrEmpty(pass))
            {
                MessageBox.Show("Введите логин и пароль!");
                return;
            }

            using (NpgsqlConnection conn = db.GetConnection())
            {
                try
                {
                    conn.Open();
                    // Ищем пользователя
                    string sql = "SELECT role, linked_computer_id FROM app_users WHERE username = @u AND password = @p";

                    using (NpgsqlCommand cmd = new NpgsqlCommand(sql, conn))
                    {
                        cmd.Parameters.AddWithValue("@u", login);
                        cmd.Parameters.AddWithValue("@p", pass);

                        using (NpgsqlDataReader reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                // Если нашли - запоминаем роль и ID
                                UserRole = reader["role"].ToString();

                                if (reader["linked_computer_id"] != DBNull.Value)
                                    LinkedComputerId = Convert.ToInt32(reader["linked_computer_id"]);
                                else
                                    LinkedComputerId = null;

                                IsAuthenticated = true;
                                this.Close(); // Закрываем окно входа -> открывается главная
                            }
                            else
                            {
                                MessageBox.Show("Неверный логин или пароль!");
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Ошибка подключения: " + ex.Message);
                }
            }
        }
    }
}