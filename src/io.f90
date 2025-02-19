!----------------------------------------------------------------------!
! io.f90                                                               !
!                                                                      !
! Module containing input/output routines.                             !
!                                                                      !
! C. D. Woodgate,  Warwick                                        2023 !
!----------------------------------------------------------------------!
module io

  use kinds
  use shared_data
  use command_line
  use display
  
  implicit none

  contains

  !--------------------------------------------------------------------!
  ! Subroutine to write software version, date, and time               !
  !                                                                    !
  ! C. D. Woodgate,  Warwick                                      2023 !
  !--------------------------------------------------------------------!
  subroutine write_info(point)

    character (len=1) point
    character (len=10) date,time

    ! Get date and time
    call date_and_time(date=date,time=time)

    write(6,'(/,72("="))')
    write(6,'(18x,"Bonte Warlo Version 0.1.2, 08.01.24")')
    write(6,'(72("-"))')

    if (point .eq. 's') then
      write(6,'(15x,"This run started at",1x,a," on",1x,a)')           &
               time(1:2)//":"//time(3:4)//":"//time(5:6),              &
               date(7:8)//"."//date(5:6)//"."//date(1:4)
    else if(point .eq. 'f') then
      write(6,'(15x,"This run finished at",1x,a," on",1x,a)')          &
               time(1:2)//":"//time(3:4)//":"//time(5:6),              &
               date(7:8)//"."//date(5:6)//"."//date(1:4)
    endif

    write(6,'(72("="),/)' )

  end subroutine write_info

  !--------------------------------------------------------------------!
  ! Subroutine to make directories for storing data                    !
  !                                                                    !
  ! C. D. Woodgate,  Warwick                                      2023 !
  !--------------------------------------------------------------------!
  subroutine make_data_directories(my_rank)
    integer :: my_rank

    ! make a directory for the grid states, diagnostics, 
    ! and radial_densities for each thread
    if(my_rank == 0) call execute_command_line('mkdir -p grids')
    if(my_rank == 0) call execute_command_line('mkdir -p diagnostics')
    if(my_rank == 0) call execute_command_line('mkdir -p radial_densities')
  end subroutine make_data_directories

  !--------------------------------------------------------------------!
  ! Subroutine to parse control file                                   !
  !                                                                    !
  ! C. D. Woodgate,  Warwick                                      2023 !
  !--------------------------------------------------------------------!
  subroutine read_control_file(filename, parameters, my_rank)

    character(len=*), intent(in) :: filename
    logical, dimension(11) :: check
    type(run_params) :: parameters
    character(len=100) :: buffer, label
    integer :: line, pos, ios, my_rank
    logical :: exists

    check = .false.

    ios=0; line=0

    ! Defaults if these are not specified.
    parameters%wc_range = 2
    parameters%delta_T = 1
    parameters%T_steps = 1
    parameters%lro = .false.
    parameters%nbr_swap = .false.
    parameters%sample_steps = 1000
    parameters%burn_in = .false.
    parameters%dump_grids = .false.
    parameters%burn_in_steps = 1000

    inquire(file=trim(filename), exist=exists)

    if (.not. exists) then
      stop 'Could not find input file ' // trim(filename)
    end if

    if(my_rank == 0) then
      write(6,'(26("-"),x,"Parsing input file",x,26("-"),/)')
    end if

    open(15, file=filename, iostat=ios)

    do while (ios==0)

      read(15, "(A)", iostat=ios) buffer

      if(ios==0) then
        line=line+1

        pos = scan(buffer, '=')
        label=buffer(1:pos-1)
        buffer = buffer(pos+1:)

        select case (label)
        case ('mode')  
          read(buffer, *, iostat=ios) parameters%mode
          check(1) = .true.
        case ('n_1')  
          read(buffer, *, iostat=ios) parameters%n_1
          check(2) = .true.
        case ('n_2')  
          read(buffer, *, iostat=ios) parameters%n_2
          check(3) = .true.
        case ('n_3')  
          read(buffer, *, iostat=ios) parameters%n_3
          check(4) = .true.
        case ('burn_in')  
          read(buffer, *, iostat=ios) parameters%burn_in
        case ('burn_in_steps')  
          read(buffer, *, iostat=ios) parameters%burn_in_steps
        case ('n_mc_steps')  
          read(buffer, *, iostat=ios) parameters%mc_steps
          check(5) = .true.
        case ('sample_steps')  
          read(buffer, *, iostat=ios) parameters%sample_steps
        case ('n_species')  
          read(buffer, *, iostat=ios) parameters%n_species
          check(6) = .true.
        case ('lattice')  
          read(buffer, *, iostat=ios) parameters%lattice
          check(7) = .true.
        case ('lattice_parameter')  
          read(buffer, *, iostat=ios) parameters%lattice_parameter
          check(8) = .true.
        case ('interaction_file')  
          read(buffer, *, iostat=ios) parameters%interaction_file
          check(9) = .true.
        case ('interaction_range')  
          read(buffer, *, iostat=ios) parameters%interaction_range
          check(10) = .true.
        case ('wc_range')  
          read(buffer, *, iostat=ios) parameters%wc_range
        case ('T')  
          read(buffer, *, iostat=ios) parameters%T
          check(11) = .true.
        case ('delta_T')  
          read(buffer, *, iostat=ios) parameters%delta_T
        case ('T_steps')  
          read(buffer, *, iostat=ios) parameters%T_steps
        case ('dump_grids')  
          read(buffer, *, iostat=ios) parameters%dump_grids
        case ('lro')  
          read(buffer, *, iostat=ios) parameters%lro
        case ('nbr_swap')  
          read(buffer, *, iostat=ios) parameters%nbr_swap
        case default
        end select
      end if
    end do


    allocate(parameters%species_names(parameters%n_species))
    allocate(parameters%species_concentrations(0:parameters%n_species))
    allocate(parameters%species_numbers(parameters%n_species))

    parameters%species_concentrations = 0.0_real64
    parameters%species_numbers = 0

    line=0

    close(15)

    open(15, file=filename, iostat=ios)


    do while (ios==0)

      read(15, "(A)", iostat=ios) buffer

      if(ios==0) then
        line=line+1

        pos = scan(buffer, '=')
        label=buffer(1:pos-1)
        buffer = buffer(pos+1:)

        select case (label)
        case ('species_names')  
          read(buffer, *, iostat=ios) parameters%species_names
          check(1) = .true.
        case ('species_concentrations')  
          read(buffer, *, iostat=ios) parameters%species_concentrations(1:)
        case ('species_numbers')  
          read(buffer, *, iostat=ios) parameters%species_numbers(:)
        case default
        end select
      end if
    end do

    close(15)

    if (.not. any(check)) then
      stop 'Missing parameter in input file'
    end if

  end subroutine read_control_file

  subroutine print_parse()

    print*, '###############################'
    print*, '#     Parsing input file      #'

  end subroutine print_parse

  subroutine echo_control_file(parameters)
    type(run_params) :: parameters
    integer :: i

    print*, ' Read mode = ', parameters%mode
    print*, ' Read n_1 = ', parameters%n_1
    print*, ' Read n_2 = ', parameters%n_2
    print*, ' Read n_3 = ', parameters%n_3
    print*, ' Read n_basis = ', parameters%n_basis
    print*, ' Read n_steps = ', parameters%mc_steps
    print*, ' Read n_species = ', parameters%n_species
    print*, ' Read lattice parameter = ', parameters%lattice_parameter
    print*, ' Read lattice = ', parameters%lattice
    print*, ' Read interaction_file = ', parameters%interaction_file
    print*, ' Read wc_range = ', parameters%wc_range
    print*, ' Read T = ', parameters%T
    print*, ' Read delta_T = ', parameters%delta_T
    print*, ' Read T_steps = ', parameters%T_steps
    print*, ' Read dump_grids = ', parameters%dump_grids
    print*, ' Read lro = ', parameters%lro
    print*, ' Read nbr_swap = ', parameters%nbr_swap

    ! Print specified concentrations/numbers of atoms
    if (abs(sum(parameters%species_concentrations)-1.0_real64) &
        .lt. 0.001) then
      do i=1, parameters%n_species
        print*, ' Read species ', i, ' = ', parameters%species_names(i), &
                ' at concentration ', parameters%species_concentrations(i)
      enddo
    else
      do i=1, parameters%n_species
        print*, ' Read species ', i, ' = ', parameters%species_names(i), &
                ' at ', parameters%species_numbers(i), ' atoms'
      enddo
    end if

  end subroutine echo_control_file

  !-----------------------------------------------------!
  ! Subroutine to read in exchange parameters from file !
  !-----------------------------------------------------!
  subroutine read_exchange(setup, my_rank)
    type(run_params) , intent(in) :: setup
    integer :: my_rank

    if(my_rank == 0) then
      write(6,'(15("-"),x,"Reading atom-atom interaction parameters",x,15("-"),/)')
    end if

    V_ex = 0.0_real64
    open(16, file=setup%interaction_file)
    read(16,*) V_ex   
    close(16)

    if (my_rank .eq. 0) then
      ! Print it out as a sanity check for user
      call pretty_print_exchange(setup)
    end if

    if(my_rank == 0) then
      write(6,'(72("-"),/)')
    end if

  end subroutine read_exchange

  !-----------------------------------------------------!
  ! Subroutine to read in exchange parameters from file !
  !-----------------------------------------------------!
  subroutine parse_inputs(setup, my_rank)
    type(run_params) :: setup
    integer :: my_rank
    character(len=30) :: control

    ! Parse the command line arguments
    call parse_args()

    ! Parse the name of the input file
    if(my_rank == 0) then
      write(6,'(22("-"),x,"Parsing name of input file",x,22("-"),/)')
    end if
      if(.not. get_arg('control', control)) then
        if (my_rank == 0) then
          print*, 'Input file not specified with "control=<name>"'
          print*, 'Defaulting to searching for "input.txt"'
          print*, ' '
        end if
        control = 'input.txt'
      else
        if (my_rank == 0) then
          print*, 'Input file name is: ', control
          print*, ' '
        end if
      end if

    ! Read the input file
    call read_control_file(control, setup, my_rank)

    if(my_rank == 0) then
      call echo_control_file(setup)
      write(6,'(/,20("-"),x,"Parsed input file successfully",x,20("-"),/)')
    end if

  end subroutine parse_inputs

end module io
