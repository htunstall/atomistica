!**********************************************************************
! 2D-Lookup table for correction function using cubic splines
!**********************************************************************

#include "macros.inc"

module table3d
  use libAtoms_module

  use logging, only: ilog

  implicit none

  private

  public :: table3d_t
  type table3d_t

     integer            :: nx = 1
     integer            :: ny = 1
     integer            :: nz = 1

     integer            :: nboxs

     real(DP), pointer  :: coeff(:, :, :, :)  => NULL()

  endtype table3d_t

  integer, parameter, private  :: npara = 4*4*4   ! 4^dim
  integer, parameter, private  :: ncorn = 8       ! 2^dim

  public :: init
  interface init
     module procedure table3d_init
  endinterface

  public :: del
  interface del
     module procedure table3d_del
  endinterface

  public :: eval
  interface eval
     module procedure table3d_eval
  endinterface

!  interface print
!     module procedure table3d_print, table3d_print_un
!  endinterface

!  interface prlog
!     module procedure table3d_prlog
!  endinterface

  public :: table3d_prlog

contains

  !**********************************************************************
  ! generates the coefficients for bicubic interpolation of fch(ni,nj)
  ! copyright: Keith Beardmore 30/11/93.
  !            Lars Pastewka 05/07
  !********************************************************************** 
  subroutine table3d_init(t, nx, ny, nz, values, dvdx, dvdy, dvdz, ierror)
    implicit none

    type(table3d_t), intent(inout)    :: t
    integer, intent(in)               :: nx
    integer, intent(in)               :: ny
    integer, intent(in)               :: nz
    real(DP), intent(in)              :: values(0:nx, 0:ny, 0:nz)
    real(DP), optional, intent(in)    :: dvdx(0:nx, 0:ny, 0:nz)
    real(DP), optional, intent(in)    :: dvdy(0:nx, 0:ny, 0:nz)
    real(DP), optional, intent(in)    :: dvdz(0:nx, 0:ny, 0:nz)
    integer, intent(inout), optional  :: ierror

    ! ---

    !
    ! calculate 3-d cubic parameters within each box.
    !
    ! normalised coordinates.
    !       8--<--7
    !      /|    /|
    !     5-->--6 |
    !     | 4--<|-3
    !     |/    |/
    !     1-->--2
    !

    integer, parameter     :: ix1(ncorn) = (/ 0,1,1,0,0,1,1,0 /)
    integer, parameter     :: ix2(ncorn) = (/ 0,0,1,1,0,0,1,1 /)
    integer, parameter     :: ix3(ncorn) = (/ 0,0,0,0,1,1,1,1 /)

    real(DP)               :: A(npara, npara)
    real(DP), allocatable  :: B(:, :)
    integer                :: ipiv(npara)

    integer                :: icorn, irow, icol, ibox, nx1, nx2, nx3
    integer                :: npow1, npow2, npow3, npow1m, npow2m, npow3m
    integer                :: i, j, k, nibox, njbox, ncbox, info

    ! ---

    t%nx     = nx
    t%ny     = ny
    t%nz     = nz
    t%nboxs  = nx*ny*nz

    allocate(t%coeff(t%nboxs, 4, 4, 4))
    allocate(B(npara, t%nboxs))

    !
    ! for each box, create and solve the matrix equatoion.
    !    / values of  \     /              \     / function and \
    !  a |  products  | * x | coefficients | = b |  derivative  |
    !    \within cubic/     \ of 2d cubic  /     \    values    /
    !

    !
    ! construct the matrix.
    ! this is the same for all boxes as coordinates are normalised.
    ! loop through corners.
    !

    do icorn = 1, ncorn
       irow = icorn
       nx1  = ix1(icorn)
       nx2  = ix2(icorn)
       nx3  = ix3(icorn)
       ! loop through powers of variables.
       do npow1 = 0, 3
          do npow2 = 0, 3
             do npow3 = 0, 3
                npow1m = npow1-1
                if (npow1m < 0)  npow1m=0
                npow2m = npow2-1
                if (npow2m < 0)  npow2m=0
                npow3m = npow3-1
                if (npow3m < 0)  npow3m=0
                icol = 1+4*4*npow1+4*npow2+npow3
                ! values of products within cubic and derivatives.
                A(irow        ,icol) = 1.0_DP*(       nx1**npow1        *nx2**npow2        *nx3**npow3  )
                A(irow+ncorn  ,icol) = 1.0_DP*( npow1*nx1**npow1m       *nx2**npow2        *nx3**npow3  )
                A(irow+2*ncorn,icol) = 1.0_DP*(       nx1**npow1  *npow2*nx2**npow2m       *nx3**npow3  )
                A(irow+3*ncorn,icol) = 1.0_DP*(       nx1**npow1        *nx2**npow2  *npow3*nx3**npow3m )
                A(irow+4*ncorn,icol) = 1.0_DP*( npow1*nx1**npow1m *npow2*nx2**npow2m       *nx3**npow3  )
                A(irow+5*ncorn,icol) = 1.0_DP*( npow1*nx1**npow1m       *nx2**npow2  *npow3*nx3**npow3m )
                A(irow+6*ncorn,icol) = 1.0_DP*(       nx1**npow1  *npow2*nx2**npow2m *npow3*nx3**npow3m )
                A(irow+7*ncorn,icol) = 1.0_DP*( npow1*nx1**npow1m *npow2*nx2**npow2m *npow3*nx3**npow3m )
             enddo
          enddo
       enddo
    enddo

    !
    ! construct the 16 r.h.s. vectors ( 1 for each box ).
    ! loop through boxes.
    !

    B(:, :) = 0.0
    do nibox = 0, nx-1
       do njbox = 0, ny-1
          do ncbox = 0, nz-1
             icol = 1+t%nx*(t%ny*ncbox+njbox)+nibox
             do icorn = 1, ncorn
                irow = icorn
                nx1  = ix1(icorn)+nibox
                nx2  = ix2(icorn)+njbox
                nx3  = ix3(icorn)+ncbox
                ! values of function and derivatives at corner.
                B(irow         ,icol) = values(nx1, nx2, nx3)
                !   all derivatives are supposed to be zero
                if (present(dvdx)) then
                   B(irow+ ncorn  ,icol) = dvdx(nx1, nx2, nx3)
                endif
                if (present(dvdy)) then
                   B(irow+ 2*ncorn,icol) = dvdy(nx1, nx2, nx3)
                endif
                if (present(dvdz)) then
                   B(irow+ 3*ncorn,icol) = dvdz(nx1, nx2, nx3)
                endif
             enddo
          enddo
       enddo
    enddo

    !
    ! solve by gauss-jordan elimination with full pivoting.
    !

!    call gaussjhc(a,npara,npara,b,t%nboxs,t%nboxs)
    call dgesv(npara, t%nboxs, A, npara, ipiv, B, npara, info)

    if (info /= 0) then
       RAISE_ERROR("dgesv failed.", ierror)
    endif

    !
    ! get the coefficient values.
    !

    do ibox = 1, t%nboxs
       icol = ibox
       do i = 1, 4
          do j = 1, 4
             do k = 1, 4
                irow=4*4*(i-1)+4*(j-1)+k
                t%coeff(ibox,i,j,k) = B(irow,icol)
             enddo
          enddo
       enddo
    enddo

    deallocate(B)

  endsubroutine table3d_init


  !**********************************************************************
  ! Free memory allocated for the spline coefficients
  !********************************************************************** 
  elemental subroutine table3d_del(t)
    implicit none

    type(table3d_t), intent(inout)  :: t

    ! ---

    deallocate(t%coeff)

  endsubroutine table3d_del


  !**********************************************************************
  ! Compute function values and derivatives
  !
  ! bicubic interpolation of hch.
  ! assumes 0.0 <= nhi,nci < 4.0
  ! copyright: Keith Beardmore 30/11/93.
  !            Lars Pastewka 05/07
  !
  !********************************************************************** 
  subroutine table3d_eval(t, nti, ntj, nconji, fcc, dfccdi, dfccdj, dfccdc)
    implicit none

    type(table3d_t), intent(in)  :: t
    real(DP), intent(in)         :: nti
    real(DP), intent(in)         :: ntj
    real(DP), intent(in)         :: nconji
    real(DP), intent(out)        :: fcc
    real(DP), intent(out)        :: dfccdi
    real(DP), intent(out)        :: dfccdj
    real(DP), intent(out)        :: dfccdc

    ! ---

    integer   :: nibox, njbox, ncbox, ibox, i, j, k
    real(DP)  :: x1, x2, x3
    real(DP)  :: sfcc, sfccdj, sfccdc
    real(DP)  :: tfcc, tfccdc
    real(DP)  :: coefij

    !
    !   find which box we're in and convert to normalised coordinates.
    !

    nibox = int( nti )
    x1    = nti - nibox
    njbox = int( ntj )
    x2    = ntj - njbox
    ncbox = int( nconji )
    x3    = nconji - ncbox

    ibox = 1+t%nx*(t%ny*ncbox+njbox)+nibox

!!$    if (x1 == 0.0 .and. x2 == 0.0 .and. x3 == 0.0) then
!!$
!!$       fcc    = t%coeff(ibox, 1, 1, 1)
!!$       dfccdi = 0.0_DP
!!$       dfccdj = 0.0_DP
!!$       dfccdc = 0.0_DP
!!$
!!$    else

       fcc    = 0.0
       dfccdi = 0.0
       dfccdj = 0.0
       dfccdc = 0.0
       do i = 4, 1, -1
          sfcc   = 0.0
          sfccdj = 0.0
          sfccdc = 0.0
          do j = 4, 1, -1
             tfcc   = 0.0
             tfccdc = 0.0
             do k = 4, 1, -1
                            coefij = t%coeff(ibox,i,j,k)
                            tfcc   =   tfcc*x3+       coefij
                if (k > 1)  tfccdc = tfccdc*x3+ (k-1)*coefij
             enddo
                         sfcc   = sfcc   *x2+       tfcc
             if (j > 1)  sfccdj = sfccdj *x2+ (j-1)*tfcc
                         sfccdc = sfccdc *x2+       tfccdc
          enddo
                      fcc    = fcc    *x1+       sfcc
          if (i > 1)  dfccdi = dfccdi *x1+ (i-1)*sfcc
                      dfccdj = dfccdj *x1+       sfccdj
                   dfccdc = dfccdc *x1+       sfccdc
       enddo

!!$    endif

  endsubroutine table3d_eval


  !>
  !! Print to screen
  !!
  !! Print to screen
  !<
  subroutine table3d_print(this, indent)
    implicit none

    type(table3d_t), intent(in)    :: this
    integer, intent(in), optional  :: indent

    ! ---

    call table3d_print_un(7, this)

  endsubroutine table3d_print


  !>
  !! Print to log file
  !!
  !! Print to log file
  !<
  subroutine table3d_prlog(this, indent)
    implicit none

    type(table3d_t), intent(in)    :: this
    integer, intent(in), optional  :: indent

    ! ---

    call table3d_print_un(ilog, this, indent)

  endsubroutine table3d_prlog


  !>
  !! Print to unit
  !!
  !! Print to unit
  !<
  subroutine table3d_print_un(un, this, indent)
    implicit none

    integer, intent(in)            :: un
    type(table3d_t), intent(in)    :: this
    integer, intent(in), optional  :: indent
    
    ! ---

    integer          :: i, j, k
    real(DP)         :: row(0:this%nx-1), dummy1, dummy2, dummy3
    character(1000)  :: fmt

    ! ---

    if (present(indent)) then
       fmt = "(" // (indent+5) // "X," // (this%nx+1) // "I20)"
    else
       fmt = "(5X," // (this%nx+1) // "I20)"
    endif

    write (un, fmt)  (/ ( i, i=0, this%nx-1 ) /)

    if (present(indent)) then
       fmt = "(" // indent // "X,I3,' -'," // (this%nx+1) // "ES20.10)"
    else
       fmt = "(4I,1X," // (this%nx+1) // "ES20.10)"
    endif

    do k = 0, this%nz-1
       do j = 0, this%ny-1
          do i = 0, this%nx-1
             call eval(this, i*1.0_DP, j*1.0_DP, k*1.0_DP, row(i), dummy1, dummy2, dummy3)
          enddo

          write (un, fmt)  j, row
       enddo

       write (un, *)
    enddo

  endsubroutine table3d_print_un

endmodule table3d