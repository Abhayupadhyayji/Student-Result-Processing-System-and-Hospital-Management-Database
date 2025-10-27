

## 1. Project Overview

This project implements a relational database to handle core hospital functions: patient registration, doctor scheduling, visit records, billing calculations and status updates. Deliverables include SQL schema, sample data, queries for appointments/payments, stored procedures for billing, triggers for discharge/status updates, and sample visit/billing reports.

---

## 2. Database Schema

Tables: `patients`, `doctors`, `departments`, `visits`, `services`, `bills`, `bill_items`, `appointments`.

### ER notes (simple):

* A `patient` can have many `visits` and `appointments`.
* A `doctor` belongs to a `department` and has many `visits` and `appointments`.
* A `visit` may generate a `bill` composed of `bill_items` referencing `services`.

### CREATE TABLE statements

```sql
CREATE TABLE departments (
  department_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT
);

CREATE TABLE patients (
  patient_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  dob DATE,
  gender ENUM('Male','Female','Other'),
  phone VARCHAR(20),
  email VARCHAR(120),
  address TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE doctors (
  doctor_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  department_id INT,
  phone VARCHAR(20),
  email VARCHAR(120),
  consultation_fee DECIMAL(10,2) DEFAULT 0.00,
  FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

CREATE TABLE appointments (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  appointment_dt DATETIME NOT NULL,
  status ENUM('Scheduled','Completed','Cancelled','No-Show') DEFAULT 'Scheduled',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

CREATE TABLE visits (
  visit_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  visit_dt DATETIME DEFAULT CURRENT_TIMESTAMP,
  reason VARCHAR(255),
  diagnosis TEXT,
  discharge_dt DATETIME NULL,
  status ENUM('Open','Discharged','Inpatient') DEFAULT 'Open',
  bill_id INT NULL,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

CREATE TABLE services (
  service_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) UNIQUE,
  name VARCHAR(150) NOT NULL,
  price DECIMAL(10,2) NOT NULL
);

CREATE TABLE bills (
  bill_id INT AUTO_INCREMENT PRIMARY KEY,
  visit_id INT UNIQUE,
  patient_id INT NOT NULL,
  total_amount DECIMAL(12,2) DEFAULT 0.00,
  tax DECIMAL(10,2) DEFAULT 0.00,
  discount DECIMAL(10,2) DEFAULT 0.00,
  net_amount DECIMAL(12,2) DEFAULT 0.00,
  status ENUM('Unpaid','Paid','Partially Paid') DEFAULT 'Unpaid',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (visit_id) REFERENCES visits(visit_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE bill_items (
  bill_item_id INT AUTO_INCREMENT PRIMARY KEY,
  bill_id INT NOT NULL,
  service_id INT NOT NULL,
  qty INT DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  FOREIGN KEY (bill_id) REFERENCES bills(bill_id),
  FOREIGN KEY (service_id) REFERENCES services(service_id)
);
```

---

## 3. Sample Data (inserts)

```sql
-- Departments
INSERT INTO departments (name, description) VALUES
('General Medicine','General illnesses'),
('Pediatrics','Child health'),
('Orthopedics','Bones and joints');

-- Doctors
INSERT INTO doctors (first_name,last_name,department_id,consultation_fee) VALUES
('Amit','Sharma',1,300.00),
('Nina','Verma',2,350.00),
('Rahul','Singh',3,400.00);

-- Patients
INSERT INTO patients (first_name,last_name,dob,gender,phone,email,address) VALUES
('Suresh','Kumar','1980-05-12','Male','9876543210','suresh@example.com','123 MG Road'),
('Priya','Gupta','1992-08-21','Female','9123456780','priya@example.com','45 Park Street');

-- Services
INSERT INTO services (code,name,price) VALUES
('CONS','Consultation',0.00),
('XRAY','X-Ray Chest',500.00),
('CBC','Complete Blood Count',250.00),
('MED','Medication',150.00);

-- Appointments
INSERT INTO appointments (patient_id,doctor_id,appointment_dt) VALUES
(1,1,'2025-10-27 10:00:00'),
(2,2,'2025-10-27 11:00:00');

-- Visits
INSERT INTO visits (patient_id,doctor_id,visit_dt,reason,status) VALUES
(1,1,'2025-10-26 09:30:00','Fever and cough','Open');
```

---

## 4. Billing: Stored Procedures & Functions

### Billing calculation stored procedure

Calculates bill items, applies tax and discount, populates `bills` and `bill_items`, and updates `visits.bill_id`.

```sql
DELIMITER $$
CREATE PROCEDURE generate_bill(
  IN p_visit_id INT,
  IN p_patient_id INT,
  IN p_tax_pct DECIMAL(5,2),
  IN p_discount_amt DECIMAL(10,2)
)
BEGIN
  DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_net DECIMAL(12,2) DEFAULT 0.00;

  -- create empty bill
  INSERT INTO bills (visit_id, patient_id) VALUES (p_visit_id, p_patient_id);
  SET @bill_id = LAST_INSERT_ID();

  -- Example: add consultation fee as a bill item (fetch doctor fee)
  INSERT INTO bill_items (bill_id, service_id, qty, unit_price, amount)
  SELECT @bill_id, s.service_id, 1, d.consultation_fee, d.consultation_fee
  FROM visits v JOIN doctors d ON v.doctor_id = d.doctor_id
  JOIN services s ON s.code = 'CONS'
  WHERE v.visit_id = p_visit_id;

  -- Sum current bill items
  SELECT SUM(amount) INTO v_total FROM bill_items WHERE bill_id = @bill_id;
  IF v_total IS NULL THEN SET v_total = 0; END IF;

  -- apply tax and discount
  UPDATE bills SET total_amount = v_total, tax = ROUND(v_total * (p_tax_pct/100),2),
    discount = p_discount_amt,
    net_amount = ROUND(v_total + (v_total * (p_tax_pct/100)) - p_discount_amt,2)
  WHERE bill_id = @bill_id;

  -- link visit -> bill
  UPDATE visits SET bill_id = @bill_id WHERE visit_id = p_visit_id;
END$$
DELIMITER ;
```

**Usage example:**

```sql
CALL generate_bill(1,1,5.00,50.00);
```

---

## 5. Triggers

### Trigger: set appointment status when visit is created

```sql
DELIMITER $$
CREATE TRIGGER trg_after_visit_insert
AFTER INSERT ON visits
FOR EACH ROW
BEGIN
  -- Mark any matching appointment as Completed
  UPDATE appointments
  SET status = 'Completed'
  WHERE patient_id = NEW.patient_id
    AND doctor_id = NEW.doctor_id
    AND DATE(appointment_dt) = DATE(NEW.visit_dt)
    AND status = 'Scheduled';
END$$
DELIMITER ;
```

### Trigger: on discharge update visit status and set discharge_dt

```sql
DELIMITER $$
CREATE TRIGGER trg_before_visit_update
BEFORE UPDATE ON visits
FOR EACH ROW
BEGIN
  IF NEW.status = 'Discharged' AND OLD.status <> 'Discharged' THEN
    SET NEW.discharge_dt = IFNULL(NEW.discharge_dt, NOW());
  END IF;
END$$
DELIMITER ;
```

---

## 6. Useful Queries / Reports

### A. Upcoming Appointments (next 7 days)

```sql
SELECT a.appointment_id, p.first_name, p.last_name, d.first_name AS doctor_first, d.last_name AS doctor_last, a.appointment_dt, a.status
FROM appointments a
JOIN patients p USING (patient_id)
JOIN doctors d USING (doctor_id)
WHERE a.appointment_dt BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
ORDER BY a.appointment_dt;
```

### B. Patient Visit History

```sql
SELECT v.visit_id, v.visit_dt, d.first_name AS doctor_fn, v.reason, v.diagnosis, v.status, b.net_amount
FROM visits v
LEFT JOIN doctors d ON v.doctor_id = d.doctor_id
LEFT JOIN bills b ON v.bill_id = b.bill_id
WHERE v.patient_id = 1
ORDER BY v.visit_dt DESC;
```

### C. Outstanding Bills

```sql
SELECT b.bill_id, p.first_name, p.last_name, b.net_amount, b.status, b.created_at
FROM bills b JOIN patients p ON b.patient_id = p.patient_id
WHERE b.status <> 'Paid'
ORDER BY b.created_at;
```

### D. Daily Visit Summary (report)

```sql
SELECT DATE(visit_dt) AS visit_date, COUNT(*) AS total_visits,
  SUM(CASE WHEN status='Discharged' THEN 1 ELSE 0 END) AS discharged_count
FROM visits
GROUP BY DATE(visit_dt)
ORDER BY visit_date DESC;
```

---

## 7. Implementation Notes (DBeaver / MySQL)

* Use MySQL 5.7+ or 8.0+.
* Import the SQL file in DBeaver: connect to database, open SQL editor, run the script.
* Use transactions for multi-step operations (e.g., creating a visit and billing together).
* Indexes: add indexes on `appointments(appointment_dt)`, `visits(visit_dt)`, `bills(status)` for performance.

---

## 8. Testing & Validation

* Insert test patients, doctors, appointments.
* Create a `visit`, call `generate_bill`, then verify `bills` and `bill_items` and that `visits.bill_id` is set.
* Test triggers by inserting/updating visits and observing appointment/status updates.

---

## 9. Future Enhancements

* Add `payments` table to record partial payments and payment methods.
* Add `rooms` and `admissions` for inpatient workflows.
* Add role-based users (receptionist, billing, doctor) and audit trails.
* REST API layer using Node/Express or Django for frontend integration.

---

## 10. Deliverables Checklist

* SQL schema (tables + FK constraints)
* Sample inserts (patients, doctors, services, appointments)
* Stored procedure `generate_bill`
* Triggers for appointment status and discharge handling
* Example queries for appointments, outstanding bills, and visit reports.

