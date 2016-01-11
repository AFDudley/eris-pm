package perform

import (
	"strings"

	"github.com/eris-ltd/eris-pm/definitions"
	"github.com/eris-ltd/eris-pm/util"

	log "github.com/eris-ltd/eris-pm/Godeps/_workspace/src/github.com/Sirupsen/logrus"
)

func RunJobs(do *definitions.Do) error {
	var err error

	// ADD DefaultAddr and DefaultSet to jobs array....
	// These work in reverse order and the addendums to the
	// the ordering from the loading process is lifo
	if len(do.DefaultSets) >= 1 {
		defaultSetJobs(do)
	}

	if do.DefaultAddr != "" {
		defaultAddrJob(do)
	}

	for _, job := range do.Package.Jobs {
		switch {

		// Util jobs
		case job.Job.Account != nil:
			announce(job.JobName, "Account")
			job.JobResult, err = SetAccountJob(job.Job.Account, do)
		case job.Job.Set != nil:
			announce(job.JobName, "Set")
			job.JobResult, err = SetValJob(job.Job.Set, do)

		// Transaction jobs
		case job.Job.Send != nil:
			announce(job.JobName, "Sent")
			job.JobResult, err = SendJob(job.Job.Send, do)
		case job.Job.RegisterName != nil:
			announce(job.JobName, "RegisterName")
			job.JobResult, err = RegisterNameJob(job.Job.RegisterName, do)
		case job.Job.Permission != nil:
			announce(job.JobName, "Permission")
			job.JobResult, err = PermissionJob(job.Job.Permission, do)
		case job.Job.Bond != nil:
			announce(job.JobName, "Bond")
			job.JobResult, err = BondJob(job.Job.Bond, do)
		case job.Job.Unbond != nil:
			announce(job.JobName, "Unbond")
			job.JobResult, err = UnbondJob(job.Job.Unbond, do)
		case job.Job.Rebond != nil:
			announce(job.JobName, "Rebond")
			job.JobResult, err = RebondJob(job.Job.Rebond, do)

		// Contracts jobs
		case job.Job.Deploy != nil:
			announce(job.JobName, "Deploy")
			job.JobResult, err = DeployJob(job.Job.Deploy, do)
		case job.Job.PackageDeploy != nil:
			announce(job.JobName, "PackageDeploy")
			job.JobResult, err = PackageDeployJob(job.Job.PackageDeploy, do)
		case job.Job.Call != nil:
			announce(job.JobName, "Call")
			job.JobResult, err = CallJob(job.Job.Call, do)

		// State jobs
		case job.Job.RestoreState != nil:
			announce(job.JobName, "RestoreState")
			job.JobResult, err = RestoreStateJob(job.Job.RestoreState, do)
		case job.Job.DumpState != nil:
			announce(job.JobName, "DumpState")
			job.JobResult, err = DumpStateJob(job.Job.DumpState, do)

		// Test jobs
		case job.Job.QueryAccount != nil:
			announce(job.JobName, "QueryAccount")
			job.JobResult, err = QueryAccountJob(job.Job.QueryAccount, do)
		case job.Job.QueryContract != nil:
			announce(job.JobName, "QueryContract")
			job.JobResult, err = QueryContractJob(job.Job.QueryContract, do)
		case job.Job.QueryName != nil:
			announce(job.JobName, "QueryName")
			job.JobResult, err = QueryNameJob(job.Job.QueryName, do)
		case job.Job.QueryVals != nil:
			announce(job.JobName, "QueryVals")
			job.JobResult, err = QueryValsJob(job.Job.QueryVals, do)
		case job.Job.Assert != nil:
			announce(job.JobName, "Assert")
			job.JobResult, err = AssertJob(job.Job.Assert, do)

		}

		if err != nil {
			return err
		}

	}

	postProcess(do)
	return nil
}

func announce(job, typ string) {
	log.WithField("=>", job).Warn("Executing Job Named")
	log.WithField("=>", typ).Info("Type")
}

func defaultAddrJob(do *definitions.Do) {
	oldJobs := do.Package.Jobs

	newJob := &definitions.Jobs{
		JobName: "defaultAddr",
		Job: &definitions.Job{
			Account: &definitions.Account{
				Address: do.DefaultAddr,
			},
		},
	}

	do.Package.Jobs = append([]*definitions.Jobs{newJob}, oldJobs...)
}

func defaultSetJobs(do *definitions.Do) {
	oldJobs := do.Package.Jobs

	newJobs := []*definitions.Jobs{}

	for _, setr := range do.DefaultSets {
		blowdUp := strings.Split(setr, "=")
		if blowdUp[0] != "" {
			newJobs = append(newJobs, &definitions.Jobs{
				JobName: blowdUp[0],
				Job: &definitions.Job{
					Set: &definitions.Set{
						Value: blowdUp[1],
					},
				},
			})
		}
	}

	do.Package.Jobs = append(newJobs, oldJobs...)
}

func postProcess(do *definitions.Do) error {
	switch do.DefaultOutput {
	case "csv":
		for _, job := range do.Package.Jobs {
			if err := util.WriteJobResultCSV(job.JobName, job.JobResult); err != nil {
				return err
			}
		}
	case "json":
		results := make(map[string]string)
		for _, job := range do.Package.Jobs {
			results[job.JobName] = job.JobResult
		}
		return util.WriteJobResultJSON(results)
	}

	if do.SummaryTable {
		// TableWriter goes here.
	}

	return nil
}
