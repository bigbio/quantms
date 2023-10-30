import pandas as pd

data = pd.DataFrame({"s": [1,2,4,7]})
print(type(data.loc[0, "s"]))
if type(data.loc[0, "s"]) !=str:
    data.loc[:, "s"] = "scan=" + data.loc[:, "s"].astype(str)
    print(data)
print(data)
