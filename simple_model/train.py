'''
Simple train model that just reads in person and writes out the person ids to model
'''
import csv


def main():
    '''
    Main function
    '''
    with open("/train/person.csv", "r") as person:
        csv_reader = csv.reader(person, delimiter=',')
        line_count = 0
        personids = []
        for row in csv_reader:
            if line_count > 0:
                personids.append(row[1])
            line_count += 1
    with open("/model/personids.csv", "w") as model:
        for person in personids:
            model.write(person + "\n")
    with open("/scratch/personids.csv", "w") as model:
        for person in personids:
            model.write(person + "\n")

if __name__ == "__main__":
    main()
