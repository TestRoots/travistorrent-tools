import argparse

import json
import math
import matplotlib.pyplot as plt
import numpy as np
import operator
import pandas as pd


def generate_plot(data, filename, dataname, title):
    filename = filename.replace(".json", "") + "-" + dataname + ".png"
    # print("Mean:", np.mean(data), "\nMin:", min(data), "\nMax:", max(data))
    plt.figure()
    plt.boxplot([data], showmeans=True, showfliers=False)
    plt.title(filename.split("/")[-2])
    plt.ylabel('delay (min)')
    plt.xticks([1], [title])
    plt.grid(True)
    plt.savefig(filename)


def pre_processing(filename):
    # Get the dataset in json format
    r = []
    with open(filename, 'r') as f:
        r = json.loads(f.read().replace('\n', ''))

    # parse to pandas
    df = pd.DataFrame(r)

    # convert columns to datetime
    df.started_at = pd.to_datetime(df.started_at)
    df.finished_at = pd.to_datetime(df.finished_at)

    # If the build was canceled, we have only the finished_at value
    df.started_at.fillna(df.finished_at, inplace=True)

    # Sort by commits arrival and start
    df = df.sort_values(by=['started_at'])

    # Convert to minutes only valid build duration
    duration = [x/60 for x in df.duration.tolist() if x > 0]

    # Difference between commits arrival - Convert to minutes to improve the view
    diff_date = [(df.started_at[i] - df.started_at[i+1]).seconds/60 for i in range(len(df.started_at) - 1)]

    generate_plot(diff_date, filename, "diff-date", "Interval Between Dates")
    generate_plot(duration, filename, "build-duration", "Build Duration")


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description='Extract commit details')

    ap.add_argument('-r', '--repository', dest='repository', type=str, required=True, help='Directory of the project to analyse')

    args = ap.parse_args()
    pre_processing("{}/repo-data-travis.json".format(args.repository))

    # to test
    # pre_processing("../build_logs/iluwatar@java-design-patterns/repo-data-travis.json")
