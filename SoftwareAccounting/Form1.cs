using Npgsql;
using System;
using System.Data;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;
using System.Net; // Для IP

namespace SoftwareAccounting
{
    public partial class Form1 : Form
    {
        DbHelper db = new DbHelper();

        // --- ЭЛЕМЕНТЫ ИНТЕРФЕЙСА ---
        TabControl tabControl;
        Panel pnlHeader;
        Label lblUserInfo;
        Button btnLogout;

        // Вкладка 1: Компьютеры
        DataGridView dgvComputers;
        PictureBox pbImage;
        Button btnLoadImage, btnAddComp, btnDelComp, btnEditComp;
        TextBox txtInv, txtModel, txtSpecs, txtIP;
        ComboBox cbEmployees;
        GroupBox grpAdminComp;
        Panel pnlPhotoRight;

        // Элементы ПО (Середина вкладки 1)
        GroupBox grpSoft;
        DataGridView dgvInstalledSoft;
        ComboBox cbSoftList;
        TextBox txtLicense;
        Button btnInstall, btnUninstall, btnEditInstSoft;

        // Вкладка 2: Справочник ПО
        DataGridView dgvSoftCatalog;
        TextBox txtSoftName, txtSoftVer;
        ComboBox cbSoftLicType; // Исправлено: используем ComboBox
        ComboBox cbCategories;
        Button btnAddSoftDef, btnEditSoftDef, btnDelSoftDef;
        GroupBox grpAdminSoftDef;

        // Вкладка 3: Отчеты
        // (dgvReports удален, так как заменен на dgvRepMain)
        ComboBox cbReports;
        Button btnShowReport, btnExport;

        // Фильтр и детализация
        Label lblLocFilter;
        ComboBox cbLocFilter;
        SplitContainer splitReport;
        DataGridView dgvRepMain;    // Главная таблица отчета
        DataGridView dgvRepDetail;  // Детализация
        Label lblDetailHeader;

        // Вкладка 4: Сотрудники
        DataGridView dgvEmployees;
        TextBox txtEmpName, txtEmpSurname, txtEmpMiddleName, txtEmpPhone;
        ComboBox cbEmpPos;
        TextBox txtLogin, txtPassword;
        ComboBox cbRole;
        Button btnAddEmp, btnEditEmp, btnDelEmp;
        GroupBox grpAdminEmp;

        // Вкладка 5: Аудит
        DataGridView dgvAudit;

        private string _userRole;
        private int? _linkedComputerId;

        public bool IsLogout { get; private set; } = false;

        public Form1(string role, int? computerId)
        {
            InitializeComponent();
            _userRole = role;
            _linkedComputerId = computerId;

            BuildInterface();
            ApplyRights();

            try
            {
                LoadEmployeesBox();
                LoadSoftwareBox();
                LoadComputers();
                LoadLocationFilter();

                if (_userRole == "admin")
                {
                    LoadSoftCatalogTab();
                    LoadCategoriesBox();
                    LoadEmployeesTab();
                    LoadPositionsBox();
                    LoadAudit();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Ошибка при запуске: " + ex.Message);
            }
        }

        private void BuildInterface()
        {
            this.Size = new Size(1350, 900);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.WindowState = FormWindowState.Maximized;

            // === 1. ВЕРХНЯЯ ПАНЕЛЬ ===
            pnlHeader = new Panel();
            pnlHeader.Dock = DockStyle.Top;
            pnlHeader.Height = 40;
            pnlHeader.BackColor = Color.WhiteSmoke;
            pnlHeader.Padding = new Padding(10);

            lblUserInfo = new Label();
            lblUserInfo.Text = "Пользователь: ...";
            lblUserInfo.AutoSize = true;
            lblUserInfo.Location = new Point(10, 12);
            lblUserInfo.Font = new Font("Arial", 10, FontStyle.Bold);

            btnLogout = new Button();
            btnLogout.Text = "Сменить пользователя";
            btnLogout.Dock = DockStyle.Right;
            btnLogout.Width = 150;
            btnLogout.BackColor = Color.LightGray;
            btnLogout.Click += BtnLogout_Click;

            pnlHeader.Controls.Add(lblUserInfo);
            pnlHeader.Controls.Add(btnLogout);

            // === 2. ТАБЫ ===
            tabControl = new TabControl();
            tabControl.Dock = DockStyle.Fill;
            tabControl.SelectedIndexChanged += TabControl_SelectedIndexChanged;

            TabPage tabComp = new TabPage("Компьютеры") { Name = "tabComp", Padding = new Padding(10) };
            TabPage tabSoftCat = new TabPage("Справочник ПО") { Name = "tabSoftCat", Padding = new Padding(10) };
            TabPage tabEmp = new TabPage("Сотрудники") { Name = "tabEmp", Padding = new Padding(0) };
            TabPage tabRep = new TabPage("Отчеты") { Name = "tabRep", Padding = new Padding(20) };
            TabPage tabAudit = new TabPage("Журнал аудита") { Name = "tabAudit", Padding = new Padding(10) };

            // --- ВКЛАДКА 1: Компьютеры ---

            grpAdminComp = new GroupBox() { Text = "Параметры Компьютера (Админ)", Dock = DockStyle.Bottom, Height = 140 };

            // Ряд 1
            Label lbl1 = new Label() { Text = "Инв. номер:", Location = new Point(20, 25), AutoSize = true };
            txtInv = new TextBox() { Location = new Point(100, 22), Width = 150 };

            Label lblModel = new Label() { Text = "Модель:", Location = new Point(270, 25), AutoSize = true };
            txtModel = new TextBox() { Location = new Point(330, 22), Width = 200 };

            Label lblIP = new Label() { Text = "IP Адрес:", Location = new Point(550, 25), AutoSize = true };
            txtIP = new TextBox() { Location = new Point(610, 22), Width = 120 };

            // Ряд 2
            Label lbl2 = new Label() { Text = "Спецификация:", Location = new Point(20, 60), AutoSize = true };
            txtSpecs = new TextBox() { Location = new Point(120, 57), Width = 410 };

            Label lblEmpLink = new Label() { Text = "Сотрудник:", Location = new Point(550, 60), AutoSize = true };
            cbEmployees = new ComboBox() { Location = new Point(620, 57), Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };

            btnAddComp = new Button() { Text = "Создать ПК", Location = new Point(20, 100), Width = 120, BackColor = Color.LightGreen };
            btnAddComp.Click += BtnAddComp_Click;

            btnEditComp = new Button() { Text = "Сохранить ПК", Location = new Point(160, 100), Width = 120, BackColor = Color.LightYellow };
            btnEditComp.Click += BtnEditComp_Click;

            btnDelComp = new Button() { Text = "Удалить ПК", Location = new Point(300, 100), Width = 120, BackColor = Color.LightPink };
            btnDelComp.Click += BtnDelComp_Click;

            grpAdminComp.Controls.Add(lbl1); grpAdminComp.Controls.Add(txtInv);
            grpAdminComp.Controls.Add(lblModel); grpAdminComp.Controls.Add(txtModel);
            grpAdminComp.Controls.Add(lblIP); grpAdminComp.Controls.Add(txtIP);
            grpAdminComp.Controls.Add(lbl2); grpAdminComp.Controls.Add(txtSpecs);
            grpAdminComp.Controls.Add(lblEmpLink); grpAdminComp.Controls.Add(cbEmployees);
            grpAdminComp.Controls.Add(btnAddComp); grpAdminComp.Controls.Add(btnEditComp); grpAdminComp.Controls.Add(btnDelComp);

            grpSoft = new GroupBox() { Text = "Установленное ПО", Dock = DockStyle.Bottom, Height = 200 };

            dgvInstalledSoft = new DataGridView() { Location = new Point(10, 20), Size = new Size(600, 170), Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left };
            dgvInstalledSoft.AllowUserToAddRows = false;
            dgvInstalledSoft.ReadOnly = true;
            dgvInstalledSoft.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            dgvInstalledSoft.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
            dgvInstalledSoft.BackgroundColor = Color.White;
            dgvInstalledSoft.SelectionChanged += DgvInstalledSoft_SelectionChanged;

            Label lblS1 = new Label() { Text = "Выберите программу:", Location = new Point(630, 30), AutoSize = true };
            cbSoftList = new ComboBox() { Location = new Point(630, 50), Width = 250, DropDownStyle = ComboBoxStyle.DropDownList };

            Label lblS2 = new Label() { Text = "Лицензия:", Location = new Point(630, 90), AutoSize = true };
            txtLicense = new TextBox() { Location = new Point(630, 110), Width = 250 };

            btnInstall = new Button() { Text = "Установить", Location = new Point(630, 150), Width = 100, BackColor = Color.LightBlue };
            btnInstall.Click += BtnInstall_Click;

            btnEditInstSoft = new Button() { Text = "Сохранить", Location = new Point(740, 150), Width = 100, BackColor = Color.LightYellow };
            btnEditInstSoft.Click += BtnEditInstSoft_Click;

            btnUninstall = new Button() { Text = "Удалить", Location = new Point(850, 150), Width = 100, BackColor = Color.LightCoral };
            btnUninstall.Click += BtnUninstall_Click;

            grpSoft.Controls.Add(dgvInstalledSoft); grpSoft.Controls.Add(lblS1); grpSoft.Controls.Add(cbSoftList);
            grpSoft.Controls.Add(lblS2); grpSoft.Controls.Add(txtLicense);
            grpSoft.Controls.Add(btnInstall); grpSoft.Controls.Add(btnEditInstSoft); grpSoft.Controls.Add(btnUninstall);

            pnlPhotoRight = new Panel() { Dock = DockStyle.Right, Width = 350, Padding = new Padding(10, 0, 0, 0) };
            pbImage = new PictureBox() { Dock = DockStyle.Top, Height = 250, BorderStyle = BorderStyle.FixedSingle, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.White };
            btnLoadImage = new Button() { Text = "Загрузить фото ПК", Dock = DockStyle.Top, Height = 40 };
            btnLoadImage.Click += BtnLoadImage_Click;
            pnlPhotoRight.Controls.Add(btnLoadImage); pnlPhotoRight.Controls.Add(pbImage);

            dgvComputers = new DataGridView() { Dock = DockStyle.Fill, BackgroundColor = SystemColors.Control, SelectionMode = DataGridViewSelectionMode.FullRowSelect, AllowUserToAddRows = false, ReadOnly = true, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill };
            dgvComputers.SelectionChanged += DgvComputers_SelectionChanged;

            tabComp.Controls.Add(dgvComputers); tabComp.Controls.Add(pnlPhotoRight); tabComp.Controls.Add(grpSoft); tabComp.Controls.Add(grpAdminComp);

            // === Вкладка 2: СПРАВОЧНИК ПО ===
            grpAdminSoftDef = new GroupBox() { Text = "Редактор Справочника ПО", Dock = DockStyle.Bottom, Height = 150 };
            Label lblSN = new Label() { Text = "Название:", Location = new Point(20, 30), AutoSize = true }; txtSoftName = new TextBox() { Location = new Point(100, 27), Width = 200 };
            Label lblSV = new Label() { Text = "Версия:", Location = new Point(320, 30), AutoSize = true }; txtSoftVer = new TextBox() { Location = new Point(380, 27), Width = 100 };
            Label lblSC = new Label() { Text = "Категория:", Location = new Point(500, 30), AutoSize = true }; cbCategories = new ComboBox() { Location = new Point(570, 27), Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };

            Label lblLT = new Label() { Text = "Тип лиц.:", Location = new Point(20, 70), AutoSize = true };
            cbSoftLicType = new ComboBox() { Location = new Point(100, 67), Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
            cbSoftLicType.Items.AddRange(new string[] { "Commercial", "Open Source", "Freeware", "Shareware", "Trial", "Subscription" });

            btnAddSoftDef = new Button() { Text = "Добавить программу", Location = new Point(20, 110), Width = 150, BackColor = Color.LightGreen };
            btnAddSoftDef.Click += BtnAddSoftDef_Click;

            btnEditSoftDef = new Button() { Text = "Обновить версию", Location = new Point(190, 110), Width = 150, BackColor = Color.LightYellow };
            btnEditSoftDef.Click += BtnEditSoftDef_Click;

            btnDelSoftDef = new Button() { Text = "Удалить программу", Location = new Point(360, 110), Width = 150, BackColor = Color.LightPink };
            btnDelSoftDef.Click += BtnDelSoftDef_Click;

            grpAdminSoftDef.Controls.Add(lblSN); grpAdminSoftDef.Controls.Add(txtSoftName); grpAdminSoftDef.Controls.Add(lblSV); grpAdminSoftDef.Controls.Add(txtSoftVer);
            grpAdminSoftDef.Controls.Add(lblSC); grpAdminSoftDef.Controls.Add(cbCategories); grpAdminSoftDef.Controls.Add(lblLT);
            grpAdminSoftDef.Controls.Add(cbSoftLicType);
            grpAdminSoftDef.Controls.Add(btnAddSoftDef); grpAdminSoftDef.Controls.Add(btnEditSoftDef); grpAdminSoftDef.Controls.Add(btnDelSoftDef);

            dgvSoftCatalog = new DataGridView() { Dock = DockStyle.Fill, BackgroundColor = SystemColors.Control, SelectionMode = DataGridViewSelectionMode.FullRowSelect, AllowUserToAddRows = false, ReadOnly = true, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill };
            dgvSoftCatalog.SelectionChanged += DgvSoftCatalog_SelectionChanged;

            tabSoftCat.Controls.Add(dgvSoftCatalog); tabSoftCat.Controls.Add(grpAdminSoftDef);

            // === Вкладка 3: СОТРУДНИКИ ===
            grpAdminEmp = new GroupBox() { Text = "Управление сотрудниками", Dock = DockStyle.Bottom, Height = 180 };

            Label lblSn = new Label() { Text = "Фамилия:", Location = new Point(20, 30), AutoSize = true }; txtEmpSurname = new TextBox() { Location = new Point(80, 27), Width = 150 };
            Label lblNm = new Label() { Text = "Имя:", Location = new Point(250, 30), AutoSize = true }; txtEmpName = new TextBox() { Location = new Point(290, 27), Width = 150 };
            Label lblMn = new Label() { Text = "Отчество:", Location = new Point(460, 30), AutoSize = true }; txtEmpMiddleName = new TextBox() { Location = new Point(520, 27), Width = 150 };

            Label lblPos = new Label() { Text = "Должность:", Location = new Point(20, 70), AutoSize = true }; cbEmpPos = new ComboBox() { Location = new Point(100, 67), Width = 250, DropDownStyle = ComboBoxStyle.DropDownList };
            Label lblPh = new Label() { Text = "Телефон:", Location = new Point(380, 70), AutoSize = true }; txtEmpPhone = new TextBox() { Location = new Point(440, 67), Width = 150 };

            Label lblLog = new Label() { Text = "Логин:", Location = new Point(700, 30), AutoSize = true, ForeColor = Color.Blue }; txtLogin = new TextBox() { Location = new Point(750, 27), Width = 120 };
            Label lblPas = new Label() { Text = "Пароль:", Location = new Point(890, 30), AutoSize = true, ForeColor = Color.Blue }; txtPassword = new TextBox() { Location = new Point(950, 27), Width = 120 };
            Label lblRl = new Label() { Text = "Роль:", Location = new Point(700, 70), AutoSize = true, ForeColor = Color.Blue }; cbRole = new ComboBox() { Location = new Point(750, 67), Width = 120, DropDownStyle = ComboBoxStyle.DropDownList };
            cbRole.Items.AddRange(new string[] { "user", "admin" });

            btnAddEmp = new Button() { Text = "Добавить сотр.", Location = new Point(20, 120), Width = 150, BackColor = Color.LightGreen };
            btnAddEmp.Click += BtnAddEmp_Click;

            btnEditEmp = new Button() { Text = "Сохранить сотр.", Location = new Point(190, 120), Width = 150, BackColor = Color.LightYellow };
            btnEditEmp.Click += BtnEditEmp_Click;

            btnDelEmp = new Button() { Text = "Удалить сотр.", Location = new Point(360, 120), Width = 150, BackColor = Color.LightPink };
            btnDelEmp.Click += BtnDelEmp_Click;

            grpAdminEmp.Controls.Add(lblSn); grpAdminEmp.Controls.Add(txtEmpSurname); grpAdminEmp.Controls.Add(lblNm); grpAdminEmp.Controls.Add(txtEmpName);
            grpAdminEmp.Controls.Add(lblMn); grpAdminEmp.Controls.Add(txtEmpMiddleName);
            grpAdminEmp.Controls.Add(lblPos); grpAdminEmp.Controls.Add(cbEmpPos);
            grpAdminEmp.Controls.Add(lblPh); grpAdminEmp.Controls.Add(txtEmpPhone);
            grpAdminEmp.Controls.Add(lblLog); grpAdminEmp.Controls.Add(txtLogin);
            grpAdminEmp.Controls.Add(lblPas); grpAdminEmp.Controls.Add(txtPassword);
            grpAdminEmp.Controls.Add(lblRl); grpAdminEmp.Controls.Add(cbRole);
            grpAdminEmp.Controls.Add(btnAddEmp); grpAdminEmp.Controls.Add(btnEditEmp); grpAdminEmp.Controls.Add(btnDelEmp);

            Panel pnlEmpGrid = new Panel() { Dock = DockStyle.Fill, Padding = new Padding(30) };
            dgvEmployees = new DataGridView() { Dock = DockStyle.Fill, BackgroundColor = SystemColors.Control, SelectionMode = DataGridViewSelectionMode.FullRowSelect, AllowUserToAddRows = false, ReadOnly = true, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill };
            dgvEmployees.SelectionChanged += DgvEmployees_SelectionChanged;

            pnlEmpGrid.Controls.Add(dgvEmployees);
            tabEmp.Controls.Add(pnlEmpGrid); tabEmp.Controls.Add(grpAdminEmp);

            // === Вкладка 4: ОТЧЕТЫ ===
            Panel pnlTopReport = new Panel() { Dock = DockStyle.Top, Height = 50 };

            Label lblRep1 = new Label() { Text = "Выберите отчет:", Location = new Point(0, 15), AutoSize = true };

            cbReports = new ComboBox() { Location = new Point(110, 12), Width = 250, DropDownStyle = ComboBoxStyle.DropDownList };
            cbReports.Items.AddRange(new string[] { "По аудиториям", "По категориям", "По назначению", "По сотрудникам" });
            cbReports.SelectedIndex = 0;
            // СОБЫТИЕ СМЕНЫ ОТЧЕТА
            cbReports.SelectedIndexChanged += CbReports_SelectedIndexChanged;

            // ФИЛЬТР АУДИТОРИЙ
            lblLocFilter = new Label() { Text = "Аудитория:", Location = new Point(370, 15), AutoSize = true, Visible = false };
            cbLocFilter = new ComboBox() { Location = new Point(440, 12), Width = 150, DropDownStyle = ComboBoxStyle.DropDownList, Visible = false };

            btnShowReport = new Button() { Text = "Сформировать", Location = new Point(620, 10), Width = 150, Height = 30 };
            btnShowReport.Click += BtnShowReport_Click;

            btnExport = new Button() { Text = "Экспорт в Excel", Location = new Point(780, 10), Width = 150, Height = 30, BackColor = Color.LightBlue };
            btnExport.Click += BtnExport_Click;

            pnlTopReport.Controls.Add(lblRep1); pnlTopReport.Controls.Add(cbReports);
            pnlTopReport.Controls.Add(lblLocFilter); pnlTopReport.Controls.Add(cbLocFilter);
            pnlTopReport.Controls.Add(btnShowReport); pnlTopReport.Controls.Add(btnExport);

            splitReport = new SplitContainer() { Dock = DockStyle.Fill, Orientation = Orientation.Horizontal };
            dgvRepMain = new DataGridView() { Dock = DockStyle.Fill, BackgroundColor = SystemColors.Control, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, AllowUserToAddRows = false, ReadOnly = true, SelectionMode = DataGridViewSelectionMode.FullRowSelect };
            dgvRepMain.SelectionChanged += DgvRepMain_SelectionChanged; // !!! ВОТ МЫ ЕГО НАЗНАЧАЕМ !!!

            dgvRepDetail = new DataGridView() { Dock = DockStyle.Fill, BackgroundColor = Color.WhiteSmoke, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, AllowUserToAddRows = false, ReadOnly = true };
            lblDetailHeader = new Label() { Text = "Детализация:", Dock = DockStyle.Top, Font = new Font("Arial", 9, FontStyle.Bold), Padding = new Padding(5) };

            splitReport.Panel1.Controls.Add(dgvRepMain);
            splitReport.Panel2.Controls.Add(dgvRepDetail);
            splitReport.Panel2.Controls.Add(lblDetailHeader);
            splitReport.Panel2Collapsed = true;

            tabRep.Controls.Add(splitReport);
            tabRep.Controls.Add(pnlTopReport);

            // === Вкладка 5: АУДИТ ===
            dgvAudit = new DataGridView() { Dock = DockStyle.Fill, BackgroundColor = SystemColors.Control, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, AllowUserToAddRows = false, ReadOnly = true };
            tabAudit.Controls.Add(dgvAudit);

            // === СБОРКА ===
            tabControl.TabPages.Add(tabComp); tabControl.TabPages.Add(tabSoftCat); tabControl.TabPages.Add(tabEmp); tabControl.TabPages.Add(tabRep); tabControl.TabPages.Add(tabAudit);

            this.Controls.Add(pnlHeader);
            this.Controls.Add(tabControl);

            // Фикс перекрытия
            pnlHeader.SendToBack();
            tabControl.BringToFront();
        }

        // --- ЛОГИКА ФИЛЬТРА ОТЧЕТОВ ---
        private void LoadLocationFilter()
        {
            cbLocFilter.Items.Clear();
            cbLocFilter.Items.Add("Все аудитории");
            DataTable dt = db.GetTable("SELECT name FROM locations ORDER BY name");
            foreach (DataRow row in dt.Rows)
            {
                cbLocFilter.Items.Add(row["name"].ToString());
            }
            cbLocFilter.SelectedIndex = 0;
        }

        private void CbReports_SelectedIndexChanged(object sender, EventArgs e)
        {
            bool showFilter = (cbReports.SelectedIndex == 0);
            lblLocFilter.Visible = showFilter;
            cbLocFilter.Visible = showFilter;
        }

        private void BtnShowReport_Click(object sender, EventArgs e)
        {
            string viewName = "";
            bool isCategoryReport = false;
            string filter = "";

            switch (cbReports.SelectedIndex)
            {
                case 0:
                    viewName = "view_report_by_location";
                    if (cbLocFilter.SelectedIndex > 0)
                    {
                        filter = $" WHERE \"Аудитория\" = '{cbLocFilter.Text}'";
                    }
                    break;
                case 1:
                    viewName = "view_report_by_category";
                    isCategoryReport = true;
                    break;
                case 2: viewName = "view_report_by_usage"; break;
                case 3: viewName = "view_report_by_employee"; break;
            }

            if (viewName != "")
            {
                string sql = $"SELECT * FROM {viewName} {filter}";
                DataTable dt = db.GetTable(sql);
                dgvRepMain.DataSource = dt;
                splitReport.Panel2Collapsed = !isCategoryReport;
            }
        }

        // !!! ВОТ ОН, ЭТОТ МЕТОД, КОТОРЫЙ ВЫЗЫВАЛ ОШИБКУ CS0103 !!!
        private void DgvRepMain_SelectionChanged(object sender, EventArgs e)
        {
            if (cbReports.SelectedIndex != 1) return;
            if (dgvRepMain.SelectedRows.Count == 0) return;

            if (dgvRepMain.Columns["Категория"] != null && dgvRepMain.SelectedRows[0].Cells["Категория"].Value != null)
            {
                string catName = dgvRepMain.SelectedRows[0].Cells["Категория"].Value.ToString();
                lblDetailHeader.Text = $"Программы в категории: {catName}";
                string sql = $"SELECT \"Программа\", \"Версия\", \"Компьютер\", \"Аудитория\" FROM view_software_details WHERE \"Категория\" = '{catName}'";
                dgvRepDetail.DataSource = db.GetTable(sql);
            }
        }

        // --- ЛОГИКА ПРАВ ДОСТУПА ---
        private void ApplyRights()
        {
            lblUserInfo.Text = $"Вы вошли как: {_userRole.ToUpper()}";

            if (_userRole == "user")
            {
                this.Text = "Учет ПО - Режим ПРОСМОТРА";
                tabControl.TabPages.RemoveByKey("tabAudit");
                tabControl.TabPages.RemoveByKey("tabEmp");
                tabControl.TabPages.RemoveByKey("tabSoftCat");

                grpAdminComp.Visible = false;
                btnLoadImage.Visible = false;

                // Настройки для пользователя
                grpSoft.Visible = true;
                grpSoft.Height = 450;

                foreach (Control c in grpSoft.Controls)
                {
                    if (c != dgvInstalledSoft) c.Visible = false;
                }
                dgvInstalledSoft.Dock = DockStyle.Fill;
            }
            else
            {
                this.Text = "Учет ПО - АДМИНИСТРАТОР";
            }
        }

        private void BtnLogout_Click(object sender, EventArgs e)
        {
            if (MessageBox.Show("Выйти из системы?", "Выход", MessageBoxButtons.YesNo) == DialogResult.Yes)
            {
                IsLogout = true;
                this.Close();
            }
        }

        private void TabControl_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (tabControl.SelectedTab == null) return;

            if (tabControl.SelectedTab.Name == "tabAudit")
            {
                LoadAudit();
            }
            else if (tabControl.SelectedTab.Name == "tabComp")
            {
                LoadComputers();
                LoadEmployeesBox();
                LoadSoftwareBox();
            }
            else if (tabControl.SelectedTab.Name == "tabEmp")
            {
                LoadEmployeesTab();
                LoadPositionsBox();
            }
            else if (tabControl.SelectedTab.Name == "tabSoftCat")
            {
                LoadSoftCatalogTab();
                LoadCategoriesBox();
            }
        }

        // --- ВАЛИДАЦИЯ ---
        private bool ValidatePhone(string phone)
        {
            if (string.IsNullOrWhiteSpace(phone))
            {
                MessageBox.Show("Введите номер телефона!");
                return false;
            }
            if (!phone.StartsWith("+7"))
            {
                MessageBox.Show("Номер должен начинаться с +7");
                return false;
            }
            if (phone.Length != 12)
            {
                MessageBox.Show("Номер должен содержать 11 цифр (+7 и еще 10).");
                return false;
            }
            string digits = phone.Substring(1);
            foreach (char c in digits)
            {
                if (!char.IsDigit(c))
                {
                    MessageBox.Show("В номере должны быть только цифры!");
                    return false;
                }
            }
            return true;
        }

        private bool ValidateNameInput(string value, string fieldName)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                MessageBox.Show($"Поле '{fieldName}' не может быть пустым!", "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }
            string pattern = "^[А-ЯЁ][а-яё]+$";
            if (!System.Text.RegularExpressions.Regex.IsMatch(value, pattern))
            {
                MessageBox.Show($"Поле '{fieldName}' имеет неверный формат! (Только русские буквы, первая заглавная)", "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }
            return true;
        }

        private bool ValidateIP(string ip)
        {
            if (string.IsNullOrWhiteSpace(ip))
            {
                MessageBox.Show("IP адрес не может быть пустым!", "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }
            IPAddress address;
            if (IPAddress.TryParse(ip, out address))
            {
                if (address.ToString().Split('.').Length == 4) return true;
            }
            MessageBox.Show("Неверный формат IP адреса!\nПример: 192.168.0.1", "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return false;
        }

        // --- ЗАГРУЗКА ДАННЫХ ---
        private void LoadPositionsBox()
        {
            string sql = "SELECT name FROM job_positions ORDER BY name";
            cbEmpPos.DisplayMember = "name";
            cbEmpPos.ValueMember = "name";
            cbEmpPos.DataSource = db.GetTable(sql);
        }

        private void LoadEmployeesTab()
        {
            string sql = @"
                SELECT e.employee_id, e.last_name as ""Фамилия"", e.first_name as ""Имя"", e.middle_name as ""Отчество"", 
                       e.position as ""Должность"", e.phone_number as ""Телефон"", u.username as ""Логин"", u.password as ""Пароль"", u.role as ""Роль""
                FROM employees e
                LEFT JOIN app_users u ON e.employee_id = u.employee_id
                ORDER BY e.last_name";
            DataTable dt = db.GetTable(sql);
            dgvEmployees.DataSource = dt;
            if (dgvEmployees.Columns["employee_id"] != null) dgvEmployees.Columns["employee_id"].Visible = false;
            if (dgvEmployees.Columns["Пароль"] != null) dgvEmployees.Columns["Пароль"].Visible = false;
        }

        private void LoadEmployeesBox()
        {
            string sql = "SELECT employee_id, (last_name || ' ' || first_name) as fio FROM employees ORDER BY last_name";
            DataTable dt = db.GetTable(sql);
            DataRow row = dt.NewRow();
            row["employee_id"] = DBNull.Value;
            row["fio"] = "--- Не закреплен ---";
            dt.Rows.InsertAt(row, 0);
            cbEmployees.DisplayMember = "fio";
            cbEmployees.ValueMember = "employee_id";
            cbEmployees.DataSource = dt;
            cbEmployees.SelectedIndex = -1;
        }

        private void LoadSoftwareBox()
        {
            string sql = "SELECT software_id, (name || ' ' || version) as full_name FROM software ORDER BY name";
            cbSoftList.DisplayMember = "full_name";
            cbSoftList.ValueMember = "software_id";
            cbSoftList.DataSource = db.GetTable(sql);
            cbSoftList.SelectedIndex = -1;
        }

        private void LoadCategoriesBox()
        {
            string sql = "SELECT category_id, name FROM software_categories ORDER BY name";
            cbCategories.DisplayMember = "name";
            cbCategories.ValueMember = "category_id";
            cbCategories.DataSource = db.GetTable(sql);
            cbCategories.SelectedIndex = -1;
        }

        private void LoadComputers()
        {
            string sql = @"
                SELECT c.computer_id, c.inventory_number, c.model, c.hardware_specs, c.ip_address, 
                       l.name as location, (e.last_name || ' ' || e.first_name) as employee_name, c.employee_id
                FROM computers c 
                LEFT JOIN locations l ON c.location_id = l.location_id
                LEFT JOIN employees e ON c.employee_id = e.employee_id";

            if (_userRole == "user" && _linkedComputerId != null)
                sql += $" WHERE c.computer_id = {_linkedComputerId}";

            sql += " ORDER BY c.computer_id";
            DataTable dt = db.GetTable(sql);
            dgvComputers.DataSource = dt;

            if (dgvComputers.Columns["computer_id"] != null) dgvComputers.Columns["computer_id"].Visible = false;
            if (dgvComputers.Columns["employee_id"] != null) dgvComputers.Columns["employee_id"].Visible = false;

            if (dgvComputers.Columns["inventory_number"] != null) dgvComputers.Columns["inventory_number"].HeaderText = "Инв. номер";
            if (dgvComputers.Columns["model"] != null) dgvComputers.Columns["model"].HeaderText = "Модель ПК";
            if (dgvComputers.Columns["hardware_specs"] != null) dgvComputers.Columns["hardware_specs"].HeaderText = "Характеристики";
            if (dgvComputers.Columns["ip_address"] != null) dgvComputers.Columns["ip_address"].HeaderText = "IP Адрес";
            if (dgvComputers.Columns["location"] != null) dgvComputers.Columns["location"].HeaderText = "Расположение";
            if (dgvComputers.Columns["employee_name"] != null) dgvComputers.Columns["employee_name"].HeaderText = "Сотрудник";
        }

        private void LoadInstalledSoft(int computerId)
        {
            string sql = $@"
                SELECT ins.installation_id, ins.software_id, s.name as ""Программа"", s.version as ""Версия"", ins.license_key as ""Лицензия"", ins.install_date as ""Дата установки""
                FROM installed_software ins
                JOIN software s ON ins.software_id = s.software_id
                WHERE ins.computer_id = {computerId}
                ORDER BY s.name";

            DataTable dt = db.GetTable(sql);
            dgvInstalledSoft.DataSource = dt;
            if (dgvInstalledSoft.Columns["installation_id"] != null) dgvInstalledSoft.Columns["installation_id"].Visible = false;
            if (dgvInstalledSoft.Columns["software_id"] != null) dgvInstalledSoft.Columns["software_id"].Visible = false;
        }

        private void LoadAudit()
        {
            dgvAudit.DataSource = db.GetTable("SELECT * FROM audit_log ORDER BY event_time DESC");
            if (dgvAudit.Columns["log_id"] != null) dgvAudit.Columns["log_id"].Visible = false;
            if (dgvAudit.Columns["event_time"] != null) dgvAudit.Columns["event_time"].HeaderText = "Время";
            if (dgvAudit.Columns["event_description"] != null) dgvAudit.Columns["event_description"].HeaderText = "Описание события";
        }

        private void LoadSoftCatalogTab()
        {
            string sql = @"
                SELECT s.software_id, s.name as ""Название"", s.version as ""Версия"", c.name as ""Категория"", s.license_type as ""Лицензия"", s.category_id 
                FROM software s LEFT JOIN software_categories c ON s.category_id = c.category_id ORDER BY s.name";
            dgvSoftCatalog.DataSource = db.GetTable(sql);
            if (dgvSoftCatalog.Columns["software_id"] != null) dgvSoftCatalog.Columns["software_id"].Visible = false;
            if (dgvSoftCatalog.Columns["category_id"] != null) dgvSoftCatalog.Columns["category_id"].Visible = false;
        }

        // --- СОБЫТИЯ ВЫБОРА ---
        private void DgvEmployees_SelectionChanged(object sender, EventArgs e)
        {
            if (dgvEmployees.SelectedRows.Count == 0) return;
            txtEmpSurname.Text = dgvEmployees.SelectedRows[0].Cells["Фамилия"].Value.ToString();
            txtEmpName.Text = dgvEmployees.SelectedRows[0].Cells["Имя"].Value.ToString();
            txtEmpMiddleName.Text = dgvEmployees.SelectedRows[0].Cells["Отчество"].Value.ToString();
            txtEmpPhone.Text = dgvEmployees.SelectedRows[0].Cells["Телефон"].Value.ToString();
            cbEmpPos.Text = dgvEmployees.SelectedRows[0].Cells["Должность"].Value.ToString();
            txtLogin.Text = dgvEmployees.SelectedRows[0].Cells["Логин"].Value.ToString();
            cbRole.Text = dgvEmployees.SelectedRows[0].Cells["Роль"].Value.ToString();
            object passVal = dgvEmployees.SelectedRows[0].Cells["Пароль"].Value;
            txtPassword.Text = (passVal != DBNull.Value) ? passVal.ToString() : "";
        }

        private void DgvComputers_SelectionChanged(object sender, EventArgs e)
        {
            if (dgvComputers.SelectedRows.Count == 0 || dgvComputers.SelectedRows[0].Cells["computer_id"].Value == null) return;
            int id = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);
            txtInv.Text = dgvComputers.SelectedRows[0].Cells["inventory_number"].Value.ToString();
            txtSpecs.Text = dgvComputers.SelectedRows[0].Cells["hardware_specs"].Value.ToString();
            object modelVal = dgvComputers.SelectedRows[0].Cells["model"].Value;
            txtModel.Text = (modelVal != DBNull.Value) ? modelVal.ToString() : "";

            // Загрузка IP
            object ipVal = dgvComputers.SelectedRows[0].Cells["ip_address"].Value;
            txtIP.Text = (ipVal != DBNull.Value) ? ipVal.ToString() : "";

            object empIdVal = dgvComputers.SelectedRows[0].Cells["employee_id"].Value;
            if (empIdVal != DBNull.Value)
                cbEmployees.SelectedValue = Convert.ToInt32(empIdVal);
            else
                cbEmployees.SelectedIndex = 0;

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("SELECT computer_image FROM computers WHERE computer_id = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    object res = cmd.ExecuteScalar();
                    if (res != null && res != DBNull.Value) pbImage.Image = Image.FromStream(new MemoryStream((byte[])res));
                    else pbImage.Image = null;
                }
            }
            LoadInstalledSoft(id);
        }

        private void DgvInstalledSoft_SelectionChanged(object sender, EventArgs e)
        {
            if (dgvInstalledSoft.SelectedRows.Count == 0 || dgvInstalledSoft.SelectedRows[0].Cells["installation_id"].Value == null) return;
            txtLicense.Text = dgvInstalledSoft.SelectedRows[0].Cells["Лицензия"].Value.ToString();
            object softIdVal = dgvInstalledSoft.SelectedRows[0].Cells["software_id"].Value;
            if (softIdVal != DBNull.Value) cbSoftList.SelectedValue = Convert.ToInt32(softIdVal);
        }

        private void DgvSoftCatalog_SelectionChanged(object sender, EventArgs e)
        {
            if (dgvSoftCatalog.SelectedRows.Count == 0) return;
            txtSoftName.Text = dgvSoftCatalog.SelectedRows[0].Cells["Название"].Value.ToString();
            txtSoftVer.Text = dgvSoftCatalog.SelectedRows[0].Cells["Версия"].Value.ToString();
            cbSoftLicType.Text = dgvSoftCatalog.SelectedRows[0].Cells["Лицензия"].Value.ToString();
            object catId = dgvSoftCatalog.SelectedRows[0].Cells["category_id"].Value;
            if (catId != DBNull.Value) cbCategories.SelectedValue = Convert.ToInt32(catId);
        }

        // --- КНОПКИ ДЕЙСТВИЙ (CRUD) ---
        private void BtnAddEmp_Click(object sender, EventArgs e)
        {
            if (!ValidateNameInput(txtEmpSurname.Text.Trim(), "Фамилия")) return;
            if (!ValidateNameInput(txtEmpName.Text.Trim(), "Имя")) return;
            if (!ValidateNameInput(txtEmpMiddleName.Text.Trim(), "Отчество")) return;
            if (!ValidatePhone(txtEmpPhone.Text.Trim())) return;
            if (!string.IsNullOrEmpty(txtLogin.Text) && string.IsNullOrEmpty(cbRole.Text))
            {
                MessageBox.Show("Если указан логин, выберите роль!");
                return;
            }

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_add_employee_full(@f, @l, @m, @p, @ph, @log, @pass, @role)", conn))
                {
                    cmd.Parameters.AddWithValue("@f", txtEmpName.Text.Trim());
                    cmd.Parameters.AddWithValue("@l", txtEmpSurname.Text.Trim());
                    cmd.Parameters.AddWithValue("@m", txtEmpMiddleName.Text.Trim());
                    cmd.Parameters.AddWithValue("@p", cbEmpPos.Text);
                    cmd.Parameters.AddWithValue("@ph", txtEmpPhone.Text.Trim());
                    cmd.Parameters.AddWithValue("@log", txtLogin.Text.Trim());
                    cmd.Parameters.AddWithValue("@pass", txtPassword.Text.Trim());
                    cmd.Parameters.AddWithValue("@role", cbRole.Text);

                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Сотрудник добавлен!");
                        LoadEmployeesTab();
                        LoadEmployeesBox();
                    }
                    catch (PostgresException ex)
                    {
                        if (ex.SqlState == "23505") MessageBox.Show("Такой логин уже занят!");
                        else MessageBox.Show("Ошибка БД: " + ex.Message);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnEditEmp_Click(object sender, EventArgs e)
        {
            if (dgvEmployees.SelectedRows.Count == 0) return;
            if (!ValidateNameInput(txtEmpSurname.Text.Trim(), "Фамилия")) return;
            if (!ValidateNameInput(txtEmpName.Text.Trim(), "Имя")) return;
            if (!ValidateNameInput(txtEmpMiddleName.Text.Trim(), "Отчество")) return;
            if (!ValidatePhone(txtEmpPhone.Text.Trim())) return;

            int id = Convert.ToInt32(dgvEmployees.SelectedRows[0].Cells["employee_id"].Value);
            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_update_employee_full(@id, @f, @l, @m, @p, @ph, @log, @pass, @role)", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@f", txtEmpName.Text.Trim());
                    cmd.Parameters.AddWithValue("@l", txtEmpSurname.Text.Trim());
                    cmd.Parameters.AddWithValue("@m", txtEmpMiddleName.Text.Trim());
                    cmd.Parameters.AddWithValue("@p", cbEmpPos.Text);
                    cmd.Parameters.AddWithValue("@ph", txtEmpPhone.Text.Trim());
                    cmd.Parameters.AddWithValue("@log", txtLogin.Text.Trim());
                    cmd.Parameters.AddWithValue("@pass", txtPassword.Text.Trim());
                    cmd.Parameters.AddWithValue("@role", cbRole.Text);

                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Обновлено!");
                        LoadEmployeesTab();
                        LoadEmployeesBox();
                        LoadComputers();
                    }
                    catch (PostgresException ex)
                    {
                        if (ex.SqlState == "23505") MessageBox.Show("Такой логин уже занят!");
                        else MessageBox.Show("Ошибка БД: " + ex.Message);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnDelEmp_Click(object sender, EventArgs e)
        {
            if (dgvEmployees.SelectedRows.Count == 0) return;
            int id = Convert.ToInt32(dgvEmployees.SelectedRows[0].Cells["employee_id"].Value);
            if (MessageBox.Show("Вы уверены?", "Удаление", MessageBoxButtons.YesNo) == DialogResult.Yes)
            {
                using (NpgsqlConnection conn = db.GetConnection())
                {
                    conn.Open();
                    using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_delete_employee(@id)", conn))
                    {
                        cmd.Parameters.AddWithValue("@id", id);
                        try
                        {
                            cmd.ExecuteNonQuery();
                            MessageBox.Show("Удалено!");
                            LoadEmployeesTab();
                            LoadEmployeesBox();
                            LoadComputers();
                        }
                        catch (Exception ex)
                        {
                            MessageBox.Show(ex.Message);
                        }
                    }
                }
            }
        }

        private void BtnAddComp_Click(object sender, EventArgs e)
        {
            string inv = txtInv.Text.Trim();
            if (string.IsNullOrWhiteSpace(inv))
            {
                MessageBox.Show("Введите инв. номер!");
                return;
            }

            string ip = txtIP.Text.Trim();
            if (!ValidateIP(ip)) return;

            object empId = (cbEmployees.SelectedValue != null) ? cbEmployees.SelectedValue : DBNull.Value;

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_add_computer(@inv, @model, @spec, @ip, 'Служебный', 1, @emp)", conn))
                {
                    cmd.Parameters.AddWithValue("@inv", inv);
                    cmd.Parameters.AddWithValue("@model", txtModel.Text.Trim());
                    cmd.Parameters.AddWithValue("@spec", txtSpecs.Text.Trim());
                    cmd.Parameters.AddWithValue("@ip", IPAddress.Parse(ip));
                    cmd.Parameters.AddWithValue("@emp", empId);

                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Компьютер успешно добавлен!");
                        LoadComputers();
                    }
                    catch (PostgresException ex)
                    {
                        if (ex.SqlState == "23505")
                        {
                            MessageBox.Show($"Компьютер с номером '{inv}' уже существует!\nПожалуйста, введите уникальный инвентарный номер.", "Дубликат", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        }
                        else
                        {
                            MessageBox.Show("Ошибка базы данных: " + ex.Message);
                        }
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show("Общая ошибка: " + ex.Message);
                    }
                }
            }
        }

        private void BtnEditComp_Click(object sender, EventArgs e)
        {
            if (dgvComputers.SelectedRows.Count == 0) return;

            string inv = txtInv.Text.Trim();
            if (string.IsNullOrWhiteSpace(inv))
            {
                MessageBox.Show("Инвентарный номер не может быть пустым!", "Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            string ip = txtIP.Text.Trim();
            if (!ValidateIP(ip)) return;

            int id = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);
            object empId = (cbEmployees.SelectedValue != null) ? cbEmployees.SelectedValue : DBNull.Value;

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                // Используем прямой UPDATE, так как процедура может быть не обновлена
                string sql = "UPDATE computers SET inventory_number = @inv, model = @model, hardware_specs = @spec, ip_address = @ip, employee_id = @emp WHERE computer_id = @id";

                using (NpgsqlCommand cmd = new NpgsqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@inv", inv);
                    cmd.Parameters.AddWithValue("@model", txtModel.Text.Trim());
                    cmd.Parameters.AddWithValue("@spec", txtSpecs.Text.Trim());
                    cmd.Parameters.AddWithValue("@ip", IPAddress.Parse(ip));
                    cmd.Parameters.AddWithValue("@emp", empId ?? DBNull.Value);

                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Данные компьютера обновлены!");
                        LoadComputers();
                    }
                    catch (PostgresException ex)
                    {
                        if (ex.SqlState == "23505")
                        {
                            MessageBox.Show($"Номер '{inv}' уже занят другим компьютером!", "Ошибка сохранения", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        }
                        else
                        {
                            MessageBox.Show("Ошибка базы данных: " + ex.Message);
                        }
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show("Общая ошибка: " + ex.Message);
                    }
                }
            }
        }

        private void BtnDelComp_Click(object sender, EventArgs e)
        {
            if (dgvComputers.SelectedRows.Count == 0) return;
            int id = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);
            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_delete_computer(@id)", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.ExecuteNonQuery();
                }
            }
            MessageBox.Show("Удалено!");
            LoadComputers();
        }

        private void BtnInstall_Click(object sender, EventArgs e)
        {
            if (dgvComputers.SelectedRows.Count == 0) return;
            if (cbSoftList.SelectedIndex == -1)
            {
                MessageBox.Show("Выберите программу!");
                return;
            }
            int compId = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);
            int softId = Convert.ToInt32(cbSoftList.SelectedValue);

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_install_software(@cid, @sid, @key)", conn))
                {
                    cmd.Parameters.AddWithValue("@cid", compId);
                    cmd.Parameters.AddWithValue("@sid", softId);
                    cmd.Parameters.AddWithValue("@key", txtLicense.Text);
                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("ПО установлено!");
                        LoadInstalledSoft(compId);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnEditInstSoft_Click(object sender, EventArgs e)
        {
            if (dgvInstalledSoft.SelectedRows.Count == 0) return;
            if (cbSoftList.SelectedIndex == -1)
            {
                MessageBox.Show("Выберите программу!");
                return;
            }
            int installId = Convert.ToInt32(dgvInstalledSoft.SelectedRows[0].Cells["installation_id"].Value);
            int compId = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);
            int softId = Convert.ToInt32(cbSoftList.SelectedValue);

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_update_installed_software(@id, @sid, @key)", conn))
                {
                    cmd.Parameters.AddWithValue("@id", installId);
                    cmd.Parameters.AddWithValue("@sid", softId);
                    cmd.Parameters.AddWithValue("@key", txtLicense.Text);
                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Запись обновлена!");
                        LoadInstalledSoft(compId);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnUninstall_Click(object sender, EventArgs e)
        {
            if (dgvInstalledSoft.SelectedRows.Count == 0) return;
            int installId = Convert.ToInt32(dgvInstalledSoft.SelectedRows[0].Cells["installation_id"].Value);
            int compId = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_uninstall_software(@id)", conn))
                {
                    cmd.Parameters.AddWithValue("@id", installId);
                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("ПО удалено!");
                        LoadInstalledSoft(compId);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnAddSoftDef_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrWhiteSpace(txtSoftName.Text))
            {
                MessageBox.Show("Введите название!");
                return;
            }
            if (string.IsNullOrWhiteSpace(cbSoftLicType.Text))
            {
                MessageBox.Show("Выберите тип лицензии!");
                return;
            }
            object catId = cbCategories.SelectedValue ?? DBNull.Value;

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_add_software_def(@n, @v, @c, @l)", conn))
                {
                    cmd.Parameters.AddWithValue("@n", txtSoftName.Text);
                    cmd.Parameters.AddWithValue("@v", txtSoftVer.Text);
                    cmd.Parameters.AddWithValue("@c", catId);
                    cmd.Parameters.AddWithValue("@l", cbSoftLicType.Text);
                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Программа добавлена!");
                        LoadSoftCatalogTab();
                        LoadSoftwareBox();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnEditSoftDef_Click(object sender, EventArgs e)
        {
            if (dgvSoftCatalog.SelectedRows.Count == 0) return;
            int id = Convert.ToInt32(dgvSoftCatalog.SelectedRows[0].Cells["software_id"].Value);
            object catId = cbCategories.SelectedValue ?? DBNull.Value;

            using (NpgsqlConnection conn = db.GetConnection())
            {
                conn.Open();
                using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_update_software_def(@id, @n, @v, @c, @l)", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@n", txtSoftName.Text);
                    cmd.Parameters.AddWithValue("@v", txtSoftVer.Text);
                    cmd.Parameters.AddWithValue("@c", catId);
                    cmd.Parameters.AddWithValue("@l", cbSoftLicType.Text);
                    try
                    {
                        cmd.ExecuteNonQuery();
                        MessageBox.Show("Справочник обновлен!");
                        LoadSoftCatalogTab();
                        LoadSoftwareBox();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show(ex.Message);
                    }
                }
            }
        }

        private void BtnDelSoftDef_Click(object sender, EventArgs e)
        {
            if (dgvSoftCatalog.SelectedRows.Count == 0) return;
            int id = Convert.ToInt32(dgvSoftCatalog.SelectedRows[0].Cells["software_id"].Value);
            if (MessageBox.Show("Удалить?", "Внимание", MessageBoxButtons.YesNo) == DialogResult.Yes)
            {
                using (NpgsqlConnection conn = db.GetConnection())
                {
                    conn.Open();
                    using (NpgsqlCommand cmd = new NpgsqlCommand("CALL sp_delete_software_def(@id)", conn))
                    {
                        cmd.Parameters.AddWithValue("@id", id);
                        try
                        {
                            cmd.ExecuteNonQuery();
                            MessageBox.Show("Удалено!");
                            LoadSoftCatalogTab();
                            LoadSoftwareBox();
                        }
                        catch (Exception ex)
                        {
                            MessageBox.Show(ex.Message);
                        }
                    }
                }
            }
        }

        private void BtnLoadImage_Click(object sender, EventArgs e)
        {
            if (dgvComputers.SelectedRows.Count == 0) return;
            OpenFileDialog ofd = new OpenFileDialog() { Filter = "Images|*.jpg;*.png;*.jpeg" };
            if (ofd.ShowDialog() == DialogResult.OK)
            {
                byte[] imgData = File.ReadAllBytes(ofd.FileName);
                int id = Convert.ToInt32(dgvComputers.SelectedRows[0].Cells["computer_id"].Value);
                using (NpgsqlConnection conn = db.GetConnection())
                {
                    conn.Open();
                    using (NpgsqlCommand cmd = new NpgsqlCommand("UPDATE computers SET computer_image = @img WHERE computer_id = @id", conn))
                    {
                        cmd.Parameters.AddWithValue("@id", id);
                        cmd.Parameters.AddWithValue("@img", imgData);
                        cmd.ExecuteNonQuery();
                    }
                }
                pbImage.Image = Image.FromFile(ofd.FileName);
                MessageBox.Show("Фото сохранено!");
            }
        }

        private void BtnExport_Click(object sender, EventArgs e)
        {
            if (dgvRepMain.Rows.Count == 0)
            {
                MessageBox.Show("Сначала сформируйте отчет!");
                return;
            }
            SaveFileDialog sfd = new SaveFileDialog() { Filter = "CSV файлы (*.csv)|*.csv", FileName = "Отчет.csv" };
            if (sfd.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    StringBuilder sb = new StringBuilder();
                    string[] columnNames = new string[dgvRepMain.Columns.Count];
                    for (int i = 0; i < dgvRepMain.Columns.Count; i++)
                    {
                        columnNames[i] = dgvRepMain.Columns[i].HeaderText;
                    }
                    sb.AppendLine(string.Join(";", columnNames));
                    foreach (DataGridViewRow row in dgvRepMain.Rows)
                    {
                        string[] cells = new string[row.Cells.Count];
                        for (int i = 0; i < row.Cells.Count; i++)
                        {
                            cells[i] = (row.Cells[i].Value?.ToString() ?? "").Replace(";", ",");
                        }
                        sb.AppendLine(string.Join(";", cells));
                    }
                    File.WriteAllText(sfd.FileName, sb.ToString(), Encoding.UTF8);
                    MessageBox.Show("Файл успешно сохранен!");
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Ошибка: " + ex.Message);
                }
            }
        }
    }
}