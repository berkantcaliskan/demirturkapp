import datetime
import unittest

from release import IOS_BUNDLE, missing_credentials, profile_metadata, version_metadata


class ReleaseMetadataTest(unittest.TestCase):
    def test_rerun_preserves_version_but_increases_both_build_numbers(self):
        first = version_metadata('version: 1.0.15+15\n', 12, 1, 100000)
        retry = version_metadata('version: 1.0.15+15\n', 12, 2, 100000)
        self.assertEqual(first['version'], '1.0.27')
        self.assertEqual(retry['version'], first['version'])
        self.assertGreater(int(retry['android_build']), int(first['android_build']))
        self.assertEqual(retry['ios_build'], '12.2')

    def test_next_release_has_higher_version_and_build(self):
        first = version_metadata('version: 1.0.15+15', 1, 99, 100000)
        second = version_metadata('version: 1.0.15+15', 2, 1, 100000)
        self.assertGreater(int(second['android_build']), int(first['android_build']))
        self.assertEqual(second['version'], '1.0.17')

    def test_invalid_build_numbers_fail_before_store_submission(self):
        for run, attempt, base in [(0, 1, 100000), (1, 100, 100000), (10000, 1, 100000), (1, 1, 2100000000)]:
            with self.assertRaises(ValueError):
                version_metadata('version: 1.0.15+15', run, attempt, base)

    def test_whitespace_credentials_are_missing(self):
        self.assertEqual(missing_credentials(('A', 'B', 'C'), {'A': 'secret', 'B': ' '}), ['B', 'C'])


class SigningProfileTest(unittest.TestCase):
    def setUp(self):
        self.now = datetime.datetime(2026, 11, 27, tzinfo=datetime.timezone.utc)
        self.profile = {
            'TeamIdentifier': ['TEAM123456'], 'ApplicationIdentifierPrefix': ['PREFIX1234'],
            'Entitlements': {'application-identifier': f'PREFIX1234.{IOS_BUNDLE}', 'get-task-allow': False},
            'ExpirationDate': datetime.datetime(2027, 1, 1),
            'UUID': '12345678-1234-1234-1234-123456789abc', 'Name': 'Demirturk App Store',
        }

    def test_distribution_profile_accepts_distinct_app_prefix(self):
        self.assertEqual(profile_metadata(self.profile, 'TEAM123456', self.now)['name'], 'Demirturk App Store')

    def test_rejects_wrong_app_team_expiry_and_non_store_profiles(self):
        for changes in [
            {'TeamIdentifier': ['OTHERTEAM']},
            {'Entitlements': {'application-identifier': 'PREFIX1234.*'}},
            {'ExpirationDate': datetime.datetime(2025, 1, 1)},
            {'ProvisionedDevices': ['device']}, {'ProvisionsAllDevices': True},
        ]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                profile_metadata({**self.profile, **changes}, 'TEAM123456', self.now)


if __name__ == '__main__':
    unittest.main()
