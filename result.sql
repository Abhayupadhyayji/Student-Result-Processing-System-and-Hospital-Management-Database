# 🎓 Student Result Processing System

## 📘 Objective
Build an SQL-based system to manage student grades, GPA/CGPA, and generate performance reports.

---

## 🛠️ Tools
- MySQL
- DBeaver / MySQL Workbench

---

## 🧩 Database Design
### Tables:
1. **Students** – stores student info  
2. **Courses** – stores course details  
3. **Semesters** – defines semester info  
4. **Grades** – stores marks, grade, GPA per subject  

---

## 📊 SQL Schema

### `schema.sql`
```sql
CREATE DATABASE student_result_system;
USE student_result_system;

CREATE TABLE Students (
  student_id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100),
  department VARCHAR(50),
  batch YEAR
);

CREATE TABLE Courses (
  course_id INT PRIMARY KEY AUTO_INCREMENT,
  course_name VARCHAR(100),
  credits INT
);

CREATE TABLE Semesters (
  semester_id INT PRIMARY KEY AUTO_INCREMENT,
  semester_name VARCHAR(20)
);

CREATE TABLE Grades (
  grade_id INT PRIMARY KEY AUTO_INCREMENT,
  student_id INT,
  course_id INT,
  semester_id INT,
  marks INT,
  grade CHAR(2),
  gpa DECIMAL(3,2),
  FOREIGN KEY (student_id) REFERENCES Students(student_id),
  FOREIGN KEY (course_id) REFERENCES Courses(course_id),
  FOREIGN KEY (semester_id) REFERENCES Semesters(semester_id)
);


INSERT INTO Students (name, department, batch)
VALUES 
('Amit Sharma', 'CSE', 2023),
('Neha Singh', 'IT', 2023),
('Ravi Patel', 'ECE', 2023);

INSERT INTO Courses (course_name, credits)
VALUES
('Database Systems', 4),
('Operating Systems', 3),
('Data Structures', 4);

INSERT INTO Semesters (semester_name)
VALUES ('Semester 1'), ('Semester 2');

INSERT INTO Grades (student_id, course_id, semester_id, marks, grade, gpa)
VALUES
(1, 1, 1, 85, 'A', 9.0),
(1, 2, 1, 78, 'B', 8.0),
(2, 1, 1, 91, 'A+', 10.0),
(3, 3, 1, 60, 'C', 6.0);

-- Calculate GPA per student
SELECT student_id, AVG(gpa) AS GPA
FROM Grades
GROUP BY student_id;

-- Rank list using window functions
SELECT student_id, 
       AVG(gpa) AS GPA,
       RANK() OVER (ORDER BY AVG(gpa) DESC) AS Rank
FROM Grades
GROUP BY student_id;

-- Pass/Fail statistics
SELECT 
  student_id,
  SUM(CASE WHEN gpa >= 5 THEN 1 ELSE 0 END) AS passed_subjects,
  SUM(CASE WHEN gpa < 5 THEN 1 ELSE 0 END) AS failed_subjects
FROM Grades
GROUP BY student_id;

DELIMITER //
CREATE TRIGGER calculate_gpa
BEFORE INSERT ON Grades
FOR EACH ROW
BEGIN
  IF NEW.marks >= 90 THEN SET NEW.gpa = 10;
  ELSEIF NEW.marks >= 80 THEN SET NEW.gpa = 9;
  ELSEIF NEW.marks >= 70 THEN SET NEW.gpa = 8;
  ELSEIF NEW.marks >= 60 THEN SET NEW.gpa = 7;
  ELSE SET NEW.gpa = 5;
  END IF;
END //
DELIMITER ;


SELECT semester_id, student_id, AVG(gpa) AS semester_gpa
FROM Grades
GROUP BY semester_id, student_id;

📄 Deliverables

SQL schema and trigger

Sample data

GPA and ranking queries

Semester summary

