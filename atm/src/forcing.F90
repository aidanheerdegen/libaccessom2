module forcing_mod

use error_handler, only : assert
use json_module
use json_kinds
use datetime_module, only : datetime
use util_mod, only : get_var_dims, replace_text
use netcdf
use field_mod, only : field_type => field
use logger_mod, only : logger_type => logger, LOG_DEBUG
use, intrinsic :: iso_fortran_env, only : stderr=>error_unit

implicit none

private

type, public :: forcing
    type(logger_type), pointer :: logger
    type(datetime) :: start_date
    type(json_file) :: json
    type(json_core) :: core
    type(json_value), pointer :: inputs
contains
    procedure, pass(self), public :: init => forcing_init
    procedure, pass(self), public :: deinit => forcing_deinit
    procedure, pass(self), public :: init_fields => forcing_init_fields
    procedure, pass(self), public :: update_field => forcing_update_field
endtype forcing

contains

!> Open forcing file and find fields
subroutine forcing_init(self, config, logger, nfields)

    class(forcing), intent(inout) :: self
    character(len=*), intent(in) :: config
    type(logger_type), target, intent(in) :: logger
    integer, intent(out) :: nfields

    type(json_value), pointer :: root

    self%logger => logger

    call self%json%initialize()
    call self%json%load_file(filename=trim(config))
    if (self%json%failed()) then
        call self%json%print_error_message(stderr)
        call assert(.false., 'forcing_init() failed')
    endif

    call self%core%initialize()
    call self%json%get(root)
    call self%core%get_child(root, "inputs", self%inputs)

    nfields = self%core%count(self%inputs)

endsubroutine forcing_init

!> Parse forcing file into a dictionary.
subroutine forcing_init_fields(self, fields, forcing_date, min_dt, calendar)

    class(forcing), intent(inout) :: self
    type(field_type), dimension(:), intent(inout) :: fields
    type(datetime), intent(in) :: forcing_date
    integer, intent(out) :: min_dt
    character(len=9), intent(out) :: calendar

    type(json_value), pointer :: fp
    integer :: i
    character(kind=CK, len=:), allocatable :: cname, fieldname
    character(kind=CK, len=:), allocatable :: filename_template
    character(len=1024) :: filename
    character(len=9) :: calendar_str
    logical :: found

    min_dt = huge(min_dt)
    calendar_str = ''

    do i=1, size(fields)
        call self%core%get_child(self%inputs, i, fp, found)
        call assert(found, "Input not found in forcing config.")

        call self%core%get(fp, "filename", filename_template, found)
        call assert(found, "Entry 'filename' not found in forcing config.")

        call self%core%get(fp, "fieldname", fieldname, found)
        call assert(found, "Entry 'fieldname' not found in forcing config.")

        call self%core%get(fp, "cname", cname, found)
        call assert(found, "Entry 'cname' not found in forcing config.")

        ! Get the shape of forcing fields
        filename = filename_for_year(filename_template, forcing_date%getYear())
        ! Initialise a new field object.
        call fields(i)%init(cname, fieldname, filename_template, filename, &
                            self%logger)

        if (fields(i)%dt < min_dt) then
            min_dt = fields(i)%dt
        endif

        if (calendar_str == '') then
            calendar_str = fields(i)%calendar
        else
            call assert(trim(calendar_str) == trim(fields(i)%calendar), &
                        "Inconsistent calendar")
        endif
    enddo

    calendar = calendar_str

endsubroutine forcing_init_fields

subroutine forcing_update_field(self, fld, forcing_date)

    class(forcing), intent(inout) :: self
    type(field_type), intent(inout) :: fld
    type(datetime), intent(in) :: forcing_date

    character(len=1024) :: filename

    ! Check whether any work needs to be done
    if (fld%timestamp == forcing_date) then
        return
    endif

    call self%logger%write(LOG_DEBUG, &
                           'forcing_update_field at '//forcing_date%isoformat())

    filename = filename_for_year(fld%filename_template, forcing_date%getYear())
    call assert(trim(filename) /= '', "File not found: "//filename)

    call fld%update_data(filename, forcing_date)

endsubroutine forcing_update_field

function filename_for_year(filename, year)
    character(len=*), intent(in) :: filename
    integer, intent(in) :: year
    character(len=1024) :: filename_for_year

    character(len=1024) :: with_year_replaced
    character(len=4) :: year_str

    write(year_str, "(I4)") year
    with_year_replaced = replace_text(filename, "{{ year }}", year_str)
    filename_for_year = replace_text(with_year_replaced, "{{year}}", year_str)
    if (trim(filename_for_year) == '') then
        filename_for_year = with_year_replaced
    endif
endfunction filename_for_year

subroutine forcing_deinit(self)
    class(forcing), intent(inout) :: self

    call self%core%destroy()
    call self%json%destroy()

end subroutine forcing_deinit

endmodule forcing_mod
