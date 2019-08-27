'''
Simple train model that just reads in person and writes out the person ids to model
'''
import csv
import random


def main():
    '''
    Main function
    '''
    with open("/infer/person.csv", "r") as person:
        csv_reader = csv.reader(person, delimiter=',')
        line_count = 0
        personids = []
        for row in csv_reader:
            if line_count > 0:
                personids.append(row[1])
            line_count += 1
    with open("/output/predictions.csv", "w") as model:
        model.write("person_id,score\n")
        for person in personids:
            model.write('{},{}\n'.format(person, random.random()))

if __name__ == "__main__":
    main()
