import json
import os
import re


class DatManager:
    format_map = {
        "string": 8,
        "foreignrow": 16,
        "i32": 4,
        "enumrow": 4,
        "bool": 1,
        "row": 8
    }

    def __init__(self, schema_json):
        with open(schema_json, "r", encoding="utf-8") as f:
            self.schema = json.load(f)
        tem = 0
        for table in self.schema["tables"]:
            for column in table["columns"]:
                if column["name"] is None:
                    column["name"] = f"Unknown{tem}"
                    tem += 1

    def get_row_length_from_schema(self, schema):
        row_length = 0
        for column in schema["columns"]:
            row_length += self.format_map[column["type"]]
        return row_length

    def get_row_length_from_data(self, data):
        num = self.get_row_number(data)
        indices = [m.start() for m in re.finditer(b"\xbb\xbb\xbb\xbb\xbb\xbb\xbb\xbb", data)]
        if len(indices) == 0:
            return -1
        for item in indices:
            if (item - 4) % num == 0:
                return (item - 4) // num
        return -1

    @staticmethod
    def get_row_number(data):
        return int.from_bytes(data[:4], "little")

    def get_schema(self, dat_file, valid_for=3):
        target_table = os.path.splitext(os.path.basename(dat_file))[0].lower()
        for table in self.schema["tables"]:
            if table["name"].lower() == target_table:
                if valid_for == 3 or table["validFor"] == valid_for:
                    return table

    @staticmethod
    def str2bytes(text):
        res = b""
        for s in text:
            res += s.encode("utf-16")[-2:]
        return res + b"\x00\x00\x00\x00"

    @staticmethod
    def array2bytes(array):
        res = b""
        for item in array:
            res += item.to_bytes(16, "little")
        return res

    @staticmethod
    def int2bytes(num, size):
        return num.to_bytes(size, "little")

    @staticmethod
    def get_array(string_data, start_index, num=None):
        if isinstance(start_index, bytes):
            num = int.from_bytes(start_index[:8], "little")
            if num == 0:
                return []
            start_index = int.from_bytes(start_index[8:], "little")
        if num is None:
            raise Exception("no num")
        res = []
        for i in range(num):
            res.append(int.from_bytes(string_data[start_index + i * 16:start_index + (i + 1) * 16], "little"))
        return res

    @staticmethod
    def get_string(string_data, start_index):
        if isinstance(start_index, bytes):
            start_index = int.from_bytes(start_index, "little")
        data_len = len(string_data)
        if start_index + 6 > data_len:
            raise Exception("index out of range")
        end = 0
        res = b""
        while start_index + 6 <= data_len:
            tem = string_data[start_index:start_index + 2]
            if tem == b"\x00\x00":
                end += 1
            res += tem
            if end == 2:
                break
            start_index += 2
        if end == 2:
            res = res[:-4]
        return res.decode("utf-16")

    def parse(self, dat_file, valid_for=3):
        with open(dat_file, "rb") as f:
            data = f.read()
        row_num = self.get_row_number(data)
        schema = self.get_schema(dat_file, valid_for)
        row_length = self.get_row_length_from_schema(schema)
        idx = 4 + row_length * row_num
        data1 = data[4:idx]
        data2 = data[idx:]
        if data2[:8] != b"\xbb\xbb\xbb\xbb\xbb\xbb\xbb\xbb":
            raise Exception(f"give {row_length},but real row_length is {self.get_row_length_from_data(data)}")
        rows = [data1[i * row_length:(i + 1) * row_length] for i in range(row_num)]
        res = []
        for row in rows:
            tem = {}
            for column in schema["columns"]:
                if column["type"] == "string":
                    tem2 = row[:self.format_map["string"]]
                    tem[column["name"]] = self.get_string(data2, tem2)
                elif column["type"] == "foreignrow" and column["array"]:
                    tem[column["name"]] = self.get_array(data2, row[:self.format_map["foreignrow"]])
                else:
                    tem2 = row[:self.format_map[column["type"]]]
                    if tem2 == b"\xfe" * self.format_map[column["type"]]:
                        tem[column["name"]] = None
                    else:
                        tem[column["name"]] = int.from_bytes(tem2, "little")
                row = row[self.format_map[column["type"]]:]
            res.append(tem)
        return res

    def write(self, json_data, dat_file, valid_for=3, table_name=None):
        if table_name is None:
            table = self.get_schema(dat_file, valid_for)
        else:
            table = None
            for item in self.schema["tables"]:
                if item["name"].lower() == table_name.lower():
                    if valid_for == 3 or item["validFor"] == valid_for:
                        table = item
                        break
        if table is None:
            raise Exception("no match table")
        check_set = set()
        for item in table["columns"]:
            check_set.add(item["name"])
        if check_set != set(json_data[0].keys()):
            raise Exception("no match column")

        data1 = [self.int2bytes(len(json_data), 4)]
        data2 = [b"\xbb" * 8]
        idx = 8

        col = table["columns"]
        strings = {}
        for item in json_data:
            i = 0
            for k, v in item.items():
                if col[i]["type"] == "string":
                    if v in strings.keys():
                        data1.append(strings[v])
                    else:
                        idx_bytes = self.int2bytes(idx, self.format_map["string"])
                        strings[v] = idx_bytes
                        data1.append(idx_bytes)
                        tem = self.str2bytes(v)
                        data2.append(tem)
                        idx += len(tem)
                elif col[i]["type"] == "foreignrow" and col[i]["array"]:
                    if len(v) == 0:
                        data1.append(self.int2bytes(0, 8) + self.int2bytes(idx, 8))
                    else:
                        idx_bytes = self.int2bytes(len(v), 8) + self.int2bytes(idx, 8)
                        data1.append(idx_bytes)
                        tem = self.array2bytes(v)
                        data2.append(tem)
                        idx += len(tem)
                else:
                    if v is None:
                        data1.append(b"\xfe" * self.format_map[col[i]["type"]])
                    else:
                        data1.append(self.int2bytes(v, self.format_map[col[i]["type"]]))
                i += 1
        res = b"".join(data1 + data2)
        with open(dat_file, "wb") as f:
            f.write(res)
        return res


if __name__ == '__main__':
    manager = DatManager("data/schema.min.json")
    data = manager.parse("data/baseitemtypes.datc64", 1)
    with open("out/baseitemtypes.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    for item in data:
        if item["Name"] != "":
            item["Name"] = "★" + item["Name"]
    manager.write(data, "out/baseitemtypes.datc64", 1, "BaseItemTypes")
