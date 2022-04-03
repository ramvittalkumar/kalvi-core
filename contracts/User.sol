// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

contract User {
    // Employee address => employerAddress
    // Used when creating a new employee
    mapping(address => address) private employee_Employer;

    // Employer-Employees mapping
    mapping(address => address[]) private employer_Employees;

    // Employee address => Employee Struct
    // Used when creating a new Employee
    mapping(address => Employee) private employee_AccountDetails;

    // Organization employerAddress => Organization
    // Used when creating an Organization
    mapping(address => Organization) private employer_Organization;

    // Employer address => employeeId => employeeAddress
    // Used when creating a new Employer
    // mapping(address => mapping(uint8 => address)) private member_Organization;
    mapping(address => mapping(uint8 => Employee)) private member_Organization;

    // Employer address => bool
    mapping(address => bool) private isEmployer;

    // Employee address => bool
    mapping(address => bool) private isEmployee;

    // User address => username
    mapping(address => string) private users;

    // Courses employer creates
    mapping(address => Course[]) private employerCourses;

    // Courses employee subscribed to
    mapping(address => Course[]) private employeeCourses;

    // Status of courses employee had subscribed to
    mapping(address => mapping(uint8 => EmployeeCourseStatus)) private employeeCourseStatus;

    // Number of top performers to be determined
    uint8 constant TOP_PERFORMERS_COUNT = 3;

    // Minimum percentage required to be eligible for leaderboard
    uint8 constant TOP_PERF_MIN_PERCENTAGE = 10;

    /**
     * Course details
     */
    struct Course {
        uint8 id; 
        string name; 
        string desc;
        address owner; 
        string url;
        uint8 bounty;
    }

    // TODO Add course, delete course functions
    // TODO Check for change in course status, emit an event on course completion that initiates streaming from employer to employee
    // TODO Function to get all the learning courses added by employer
    // TODO Employee address => List of courses enrolled and completed

    enum Access {
        Locked, // Locked by employer. Can't be unlocked by employee. No access to widrawal of funds.
        Unlocked // Unlocked by employer. Can't be unlocked by employee. No access to widrawal of funds.
    }

    /**
    * Employee course status
    */
    enum EmployeeCourseStatus {
        NOT_STARTED,
        IN_PROGRESS,
        COMPLETED
    }

    struct Employee {
        address _address; // the address of the employee
        string username; // an identifier for the employee
        Access access; // locked(0) or unlocked(1)
        uint8 _totalBounty;
    }

    struct Organization {
        address payable owner; // the owner of the Organization
        // mapping(address => Employee) employee; // the employees of the organization
        uint8 numOfEmployees; // The number of employees in the organization
    }

    /** 
     * @notice - This function is used to retrieve the username based on wallet address
     * @param _address - The address of the user.
     */
    function getUserName(address _address) external view returns(string memory username){
        return users[_address];
    }

    /**
     * @notice - Creates course
     *
     * @param _name - name of the course
     * @param _desc - description of the course
     * @param _url - url of the course
     * @param _bounty - bounty for the course
     */
    function createCourse(string memory _name, string memory _desc, 
        string memory _url, uint8 _bounty) public {
        require(
            (bytes(_name).length != 0 && bytes(_url).length != 0 && _bounty != 0), 
        "Error: Mandatory information course name/url/bounty missing"
        );

        require(
            isEmployer[msg.sender],
            "Access Restricted: Courses can be created only by an employer"
        );

        Course memory course = Course({
            id: uint8(employerCourses[msg.sender].length + 1),
            name: _name,
            desc: _desc,
            owner: msg.sender,
            url: _url,
            bounty: _bounty
        });
        employerCourses[msg.sender].push(course);
        subscribeCourse(course);
    }

    /**
     * @notice - Fetch course list based on user type
     *
     * @return courseList - list of courses  
     */
    function fetchCourses() view public returns (Course[] memory courseList) {
        Course[] memory courses;
        if (isEmployer[msg.sender]) { //Employer
            return employerCourses[msg.sender];
        } else if (isEmployee[msg.sender]) { //Employee
            return fetchIncompleteCourses();
        } else {
            return courses;
        }
    }


    /**
     * @notice - Fetch incompleted course list
     *
     * @return courseList - list of courses  
     */
    function fetchIncompleteCourses() view public returns (Course[] memory) {
        Course[] memory coursesList = employeeCourses[msg.sender];
        Course[] memory incompletedList = new Course[](coursesList.length);
        uint8 counter = 0;
        for (uint8 i = 0; i < coursesList.length; i++) {
            if(employeeCourseStatus[msg.sender][coursesList[i].id] != EmployeeCourseStatus.COMPLETED) {
                incompletedList[counter] = coursesList[i];
                counter = counter + 1;
            }
        }
        return incompletedList;
    }


    /**
     * @notice - Fetch completed course list
     *
     * @return courseList - list of courses  
     */
    function fetchCompletedCourses() view public returns (Course[] memory) {
        Course[] memory coursesList = employeeCourses[msg.sender];
        Course[] memory completedList = new Course[](coursesList.length);
        uint8 counter = 0;
        for (uint8 i = 0; i < coursesList.length; i++) {
            if(employeeCourseStatus[msg.sender][coursesList[i].id] == EmployeeCourseStatus.COMPLETED) {
                completedList[counter] = coursesList[i];
                counter = counter + 1;
            }
        }
        return completedList;
    }


    /**
     * @notice - Subscribe course
     *
     * @param _course - course
     */
    function subscribeCourse(Course memory _course) private {
        address[] memory employees = employer_Employees[msg.sender];

        // All newly added courses are subscribed to all employers by default
        for (uint8 i = 0; i < employees.length; i++) {
            employeeCourses[employees[i]].push(_course);
            employeeCourseStatus[employees[i]][_course.id] = EmployeeCourseStatus.NOT_STARTED;
        }
    }


    /**
     * @notice - Subscribe course
     */
    function subscribeCourse(address _address) private {
        Course[] memory courses = employerCourses[msg.sender];

        // All newly added courses are subscribed to all employers by default
        for (uint8 i = 0; i < courses.length; i++) {
            employeeCourses[_address].push(courses[i]);
            employeeCourseStatus[_address][courses[i].id] = EmployeeCourseStatus.NOT_STARTED;
        }
    }


    /**
     * @notice - Complete course
     *
     * @param _courseId - course ID
     * @return courseUrl - course URL
     */
    function completeCourse(uint8 _courseId) public returns (string memory courseUrl) {
        require(isEmployee[msg.sender], "Only an employee can make this request");

        Course[] memory allCourses = employeeCourses[msg.sender];
        for (uint8 i = 0; i < allCourses.length; i++) {
            if (allCourses[i].id == _courseId && employeeCourseStatus[msg.sender][allCourses[i].id] == EmployeeCourseStatus.NOT_STARTED) {
                employeeCourseStatus[msg.sender][allCourses[i].id] = EmployeeCourseStatus.COMPLETED;
                employee_AccountDetails[msg.sender]._totalBounty = employee_AccountDetails[msg.sender]._totalBounty 
                                                                    + allCourses[i].bounty;
                return allCourses[i].url;
            }
        }
        return "";
    }

    /**
     * @notice - Get course status
     *
     * @param _courseId - course ID
     * @return courseStatus - course status
     */
    function getCourseStatus(uint8 _courseId) public view returns (string memory courseStatus) {
        Course[] memory allCourses = employeeCourses[msg.sender];
        string memory status;
        for (uint8 i = 0; i < allCourses.length; i++) {
            if (allCourses[i].id == _courseId) {
                EmployeeCourseStatus cStatus = employeeCourseStatus[msg.sender][allCourses[i].id];
                    if (cStatus == EmployeeCourseStatus.NOT_STARTED) {
                        status = "NOT_STARTED";
                    } else if (cStatus == EmployeeCourseStatus.IN_PROGRESS) {
                        status = "IN_PROGRESS";
                    } else if (cStatus == EmployeeCourseStatus.COMPLETED) {
                        status = "COMPLETED";
                    }
            }
        }
        return status;
    }
    

    /**
     * @notice - Fetch total course bounty value
     *
     * @param _employeeAddress - employee address
     * @return totalBountyValue - total bounty value
     */
    function getTotalCourseBountyValue(address _employeeAddress) public view returns (uint8 totalBountyValue){
        Course[] memory courses = employeeCourses[_employeeAddress];
        totalBountyValue = 0;
        for(uint8 i = 0; i < courses.length; i++) {
            if (employeeCourseStatus[_employeeAddress][courses[i].id] == EmployeeCourseStatus.COMPLETED) {
                totalBountyValue = totalBountyValue + courses[i].bounty;
            }
        }
        return totalBountyValue;
    }


    /** 
     * @notice - This function is used to determine the type of user
     * 1 = employer. 2 = employee. 3 = unenrolled
     * @param user - The address of the user.
     */
    function getUserType(address user) external view returns(uint256){
        if(isEmployer[user]){
            return 1;
        }else if (isEmployee[user]){
            return 2;
        }else{
            return 3;
        }
    }

    /**
     * @notice - This function is used to determine if the user is an employee of an organization.
     */
    function fetchEmployees() public view returns (Employee[] memory) {
        require(isEmployer[msg.sender], "Only an Employer can make this request");

        //determine how many employees the employer has
        uint8 numOfEmployees = employer_Organization[msg.sender].numOfEmployees;
        Employee[] memory employees = new Employee[](numOfEmployees);
        for (uint8 index = 0; index < numOfEmployees; index++) {
            employees[index] = member_Organization[msg.sender][index + 1];
        }
        return employees;
    }

    /**
     * @notice - This function is used to create a new employer/owner
     */
    function createEmployer(string memory username) public {
        require(
            !isEmployer[msg.sender],
            "You are already registered as an Employer"
        );

        // create a new organization
        Organization memory organization = Organization({
            owner: payable(msg.sender),
            numOfEmployees: 0
        });
        employer_Organization[msg.sender] = organization;
        isEmployer[msg.sender] = true;
        users[msg.sender]=username;
    }

    /**
     * @notice - This function is used to add a employee to the organization owned by an employer.
     * @param _employeeAddress - The address of the employee.
     * @param _employeeName - The username of the employee.
     */
    function addEmployee(address _employeeAddress, string memory _employeeName) public {
        require(isEmployer[msg.sender], "Only an employer can make this request");
        require(!isEmployee[_employeeAddress], "Employee is already registered to an organization");
        // Fetch the employee
        Employee memory employee = Employee({
            _address: _employeeAddress,
            username: _employeeName,
            access: Access.Locked,
            _totalBounty: 0
        });

        // get next id number for the employee
        uint8 employeeId = employer_Organization[msg.sender].numOfEmployees + 1;

        // update employee count
        employer_Organization[msg.sender].numOfEmployees = employeeId;

        // update mappings
        isEmployee[_employeeAddress] = true;
        employee_Employer[_employeeAddress] = msg.sender;
        employee_AccountDetails[_employeeAddress] = employee;
        member_Organization[msg.sender][employeeId] = employee;
        users[_employeeAddress]=_employeeName;

        // Update employer-employees mapping
        if (!isEmployeeAlreadyExist(_employeeAddress)) {
            employer_Employees[msg.sender].push(_employeeAddress);
        } 

        // Subscribe all courses to new employee
        subscribeCourse(_employeeAddress);
    }

    /**
     * @notice - Check if employee address already exist for the employer
     *
     * @param _employeeAddress - address of the employee
     * @return - flag indicating if employee already present 
     */
    function isEmployeeAlreadyExist(address _employeeAddress) private view returns(bool) {
        address[] memory employees = employer_Employees[msg.sender];

        if (employees.length == 0) { return false; }
        for (uint8 i = 0; i < employees.length; i++) {
            if (employees[i] == _employeeAddress) { return true; }
        }
        return false;
    }

    /**
     * @notice - This function is used to change the access of an employee.
     * @param _employeeAddress - The address of the employee.
     */
    function changeAccess(address _employeeAddress) public {
        require(isEmployer[msg.sender], "Only an employer can make this request");

        // current status
        Access currentAccess = employee_AccountDetails[_employeeAddress].access;

        // change the access of the employee
        if (currentAccess == Access.Locked) {
            employee_AccountDetails[_employeeAddress].access = Access.Unlocked;
        } else {
            employee_AccountDetails[_employeeAddress].access = Access.Locked;
        }
    }

    /**
     * @notice - Fetches top performers based on total completion percentage
     */
    function getTopPerformers() public view returns (Employee[] memory){
        address[] memory employeeAddesses;
        if (isEmployee[msg.sender]){
            employeeAddesses = employer_Employees[employee_Employer[msg.sender]];
        } else if (isEmployer[msg.sender]) {
            employeeAddesses = employer_Employees[msg.sender];
        }
            
        Employee[] memory employees = new Employee[](employeeAddesses.length);
        for(uint8 i = 0; i < employeeAddesses.length; i++) {
            uint8 totalBountyVal = getTotalCourseBountyValue(employeeAddesses[i]);
            // Only employees with minimum completion percentage is eligible
            if (totalBountyVal > 0) {
                employees[i] = employee_AccountDetails[employeeAddesses[i]];
            }
        }
        if (employees.length > 1) {
            sortEmployeesByTotalBounty(employees, int(employees.length -1), int(0));
        }

        uint8 counter = 0;
        uint8 previousValue = 0;
        Employee[] memory topPerformers = new Employee[](employeeAddesses.length);
        for (uint8 j = 0; j < employees.length; j++) {
            if (employees[j]._totalBounty != previousValue) {
                if (counter == TOP_PERFORMERS_COUNT) {
                break;
                }
                counter++;
            }
            topPerformers[j] = employees[j];
            previousValue = employees[j]._totalBounty;
        } 
        return topPerformers;
    }


    /**
     * @notice - Sort employees based on bounties earned
     *
     * @param arr - address of the employee
     * @param left - left pointer of array
     * @param right - right pointer of array
     */
    function sortEmployeesByTotalBounty(Employee[] memory arr, int left, int right) view private {
        int i = left;
        int j = right;
        if(i==j) return;
        uint pivot = arr[uint(left + (right - left) / 2)]._totalBounty;
        while (i >= j) {
            while (arr[uint(i)]._totalBounty < pivot) i--;
            while (pivot < arr[uint(j)]._totalBounty) j++;
            if (i >= j) {
                (arr[uint(j)], arr[uint(i)]) = (arr[uint(i)], arr[uint(j)]);
                i--;
                j++;
            }
        }
        if (left > j)
            sortEmployeesByTotalBounty(arr, left, j);
        if (i > right)
            sortEmployeesByTotalBounty(arr, i, right);
    }


    /**
     * @notice - Quick load test data for testing
     */
    function loadTestData() public {
        createEmployer("Google");
        
        //Local
        //addEmployee(parseAddr(""), "Ram");
        //addEmployee(parseAddr(""), "Sayan");
        //addEmployee(parseAddr(""), "Kaushik");

        //Injected
        addEmployee(parseAddr(""), "Ram");
        addEmployee(parseAddr(""), "Sayan");
        addEmployee(parseAddr(""), "Kaushik");

        createCourse("test1", "test1Desc", "https://www.youtube.com/watch?v=nUEBAS5r4Og", 10);
        createCourse("test2", "test2Desc", "https://www.youtube.com/watch?v=aRJA1r1Gwu0", 40);
        createCourse("test3", "test3Desc", "https://www.youtube.com/watch?v=aRJA1r1Gwu0", 20);
        createCourse("test4", "test4Desc", "https://www.youtube.com/watch?v=aRJA1r1Gwu0", 5);
    }


    /**
     * @notice - Convert String to Address value
     *
     * @param _a - address value in string format
     * @return _parsedAddress - address value in Address format
     */
    function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

}
