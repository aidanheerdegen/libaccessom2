
import pytest
from helper import Helper

@pytest.fixture
def helper():
    return Helper()

@pytest.fixture(params=['JRA55-do', 'minimal'])
def exp(request):
    yield request.param

class TestYatm:

    def test_run(self, helper, exp):
        """
        Check that the default configurations run.
        """
        ret, output = helper.run_exp(exp)
        assert ret == 0

    def test_forcing_checksums(self, helper, exp):
        """
        Test that checksums have not changed.
        """

        ret, output = helper.run_exp(exp)
        assert ret == 0

        run_checksums = helper.filter_checksums(output)
        stored_checksums = helper.checksums(exp)

        # Check that keys are the same
        assert set(run_checksums.keys()) == set(stored_checksums.keys())
        # Check that everything is the same
        assert run_checksums == stored_checksums


    def test_dates(self, helper, exp):
        """
        """


    def test_restart(self, helper, exp):
        """
        Test that model restarts at the correct date.
        """
        pass
