import _bootstrap
import unittest

from clean_term2 import clean2


class Clean2Tests(unittest.TestCase):
    def test_null_and_empty_values(self):
        self.assertIsNone(clean2(None))
        self.assertEqual(clean2(""), "")
        self.assertEqual(clean2("   "), "")

    def test_punctuation_and_invisible_spacing(self):
        self.assertEqual(clean2("++?Adenocarcinoma, NOS"), "Adenocarcinoma")
        self.assertEqual(clean2("A\u00a0B/\u2013C"), "A B C")
        self.assertEqual(clean2("A\u200bB"), "AB")
        self.assertEqual(clean2("a::b"), "a b")
        self.assertEqual(clean2("ALK-)"), "ALK\u2212)")

    def test_whole_word_rules(self):
        self.assertEqual(clean2("adenosquamous NOS"), "adenosquamous")
        self.assertEqual(clean2("nose types"), "nose types")
        self.assertEqual(clean2("A type B"), "A B")
        self.assertEqual(clean2("Type A thymoma"), "Type A thymoma")
        self.assertEqual(clean2("[NOS]"), "")

    def test_roman_numerals_and_karyotypes(self):
        self.assertEqual(clean2("CIN III, NOS"), "CIN 3")
        self.assertEqual(clean2("Grade IV"), "Grade 4")
        self.assertEqual(clean2("type IV"), "type IV")
        self.assertEqual(clean2("del (5q)"), "del(5q)")
        self.assertEqual(clean2("inv(16) (p13;q22)"), "inv(16)(p13;q22)")

    def test_case_and_spelling_behavior(self):
        self.assertEqual(clean2("Tumour"), "Tumour")
        self.assertEqual(clean2("Paget\u2019s disease"), "Paget disease")
        self.assertEqual(clean2("Non small cell"), "Nonsmall cell")

    def test_deployed_v3_rules(self):
        self.assertEqual(clean2("Tumour of the breast"), "Tumour of breast")
        self.assertEqual(clean2("with an associated neoplasm"), "with associated neoplasm")
        self.assertEqual(clean2("type a thymoma"), "type a thymoma")
        self.assertEqual(clean2("A & B"), "A and B")
        self.assertEqual(clean2("grade II/III"), "grade 2 3")
        self.assertEqual(clean2("pre pre B"), "prepreB")


if __name__ == "__main__":
    unittest.main()
