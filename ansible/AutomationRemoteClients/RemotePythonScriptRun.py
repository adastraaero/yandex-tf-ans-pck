#!/usr/bin/env python3

import json

cars = {
    "manufacures": [
    "Acura", "Alfa-Romeo", " Aston-Martin", "Audi", "Bentley", "BMW"
    ]
}


print(json.dumps(cars, indent=4))