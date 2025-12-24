using System;
using System.Data;
using System.Windows.Forms;
using Npgsql; // Подключаем библиотеку

namespace SoftwareAccounting
{
    public class DbHelper
    {
        // ВНИМАНИЕ: Замени '12345' на ТВОЙ пароль от PostgreSQL!
        private string connectionString = "Host=localhost;Port=5432;Username=postgres;Password=postgres;Database=software_inventory";

        // Метод 1: Получить таблицу данных (для SELECT)
        public DataTable GetTable(string query)
        {
            DataTable dt = new DataTable();
            try
            {
                using (NpgsqlConnection conn = new NpgsqlConnection(connectionString))
                {
                    conn.Open();
                    using (NpgsqlDataAdapter adapter = new NpgsqlDataAdapter(query, conn))
                    {
                        adapter.Fill(dt);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Ошибка БД: " + ex.Message);
            }
            return dt;
        }

        // Метод 2: Получить само подключение (нужно для Картинок и Процедур)
        public NpgsqlConnection GetConnection()
        {
            return new NpgsqlConnection(connectionString);
        }
    }
}