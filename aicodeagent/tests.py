from functions.get_file_content import get_file_content
from functions.write_file_content import write_file
from functions.run_python import run_python_file

def test_get_file_content():
    print (" ~~~~~~~~~~~~~~~~  case - 1  ~~~~~~~~~~~~~~~~~~~~~ " )
    result = get_file_content("calculator", "main.py")
    print(result)

    print (" ~~~~~~~~~~~~~~~~  case - 2  ~~~~~~~~~~~~~~~~~~~~~ " )

    result = get_file_content("calculator", "pkg/calculator.py")
    print(result)

    print (" ~~~~~~~~~~~~~~~~  case - 3  ~~~~~~~~~~~~~~~~~~~~~ " )
    result = get_file_content("calculator", "/bin/cat")
    print(result)





def test_write_file():
    result = write_file("calculator", "lorem.txt", "wait, this isn't lorem ipsum")
    print(result)

    result = write_file("calculator", "pkg/morelorem.txt", "lorem ipsum dolor sit amet")
    print(result)

    result = write_file("calculator", "/tmp/temp.txt", "this should not be allowed")
    print(result)






def test():
    result = run_python_file("calculator", "main.py")
    print(result)

    result = run_python_file("calculator", "tests.py")
    print(result)

    result = run_python_file("calculator", "../main.py")
    print(result)

    result = run_python_file("calculator", "nonexistent.py")
    print(result)



if __name__ == "__main__":
    test()


