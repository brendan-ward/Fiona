import logging

from fiona.ogrext1 cimport *

from fiona.errors import DriverIOError
from fiona._err cimport exc_wrap_pointer


log = logging.getLogger(__name__)

cdef int OGRERR_NONE = 0


cdef bint is_field_null(void *feature, int n):
    if not OGR_F_IsFieldSet(feature, n):
        return True
    else:
        return False


cdef void gdal_flush_cache(void *cogr_ds):
    retval = OGR_DS_SyncToDisk(cogr_ds)
    if retval != OGRERR_NONE:
        raise RuntimeError("Failed to sync to disk")


cdef void* gdal_open_vector(const char *path_c, int mode, drivers, options):
    cdef void* cogr_ds = NULL
    cdef void* drv = NULL
    cdef void* ds = NULL

    encoding = options.get('encoding', None)
    if encoding:
        val = encoding.encode('utf-8')
        CPLSetThreadLocalConfigOption('SHAPE_ENCODING', <const char *>val)
    else:
        CPLSetThreadLocalConfigOption('SHAPE_ENCODING', "")

    if drivers:
        for name in drivers:
            name_b = name.encode()
            name_c = name_b
            #log.debug("Trying driver: %s", name)
            drv = OGRGetDriverByName(name_c)
            if drv != NULL:
                ds = OGR_Dr_Open(drv, path_c, mode)
            if ds != NULL:
                cogr_ds = ds
                # TODO
                #collection._driver = name
                break
    else:
        cogr_ds = OGROpen(path_c, mode, NULL)
    return cogr_ds


cdef void* gdal_create(void* cogr_driver, const char *path_c, options) except *:
    cdef void* cogr_ds = NULL
    cdef char **opts = NULL

    encoding = options.get('encoding', None)
    if encoding:
        val = encoding.encode('utf-8')
        CPLSetThreadLocalConfigOption('SHAPE_ENCODING', val)
    else:
        CPLSetThreadLocalConfigOption('SHAPE_ENCODING', "")

    for k, v in options.items():
        k = k.upper().encode('utf-8')
        if isinstance(v, bool):
            v = ('ON' if v else 'OFF').encode('utf-8')
        else:
            v = str(v).encode('utf-8')
        log.debug("Set option %r: %r", k, v)
        opts = CSLAddNameValue(opts, <const char *>k, <const char *>v)

    try:
        cogr_ds = exc_wrap_pointer(
            OGR_Dr_CreateDataSource(
                cogr_driver, path_c, opts))
        return cogr_ds
    except Exception as exc:
        raise DriverIOError(str(exc))
    finally:
        CSLDestroy(opts)

# transactions are not supported in GDAL 1.x
cdef OGRErr gdal_start_transaction(void* cogr_ds, int force):
    return OGRERR_NONE
cdef OGRErr gdal_commit_transaction(void* cogr_ds):
    return OGRERR_NONE
cdef OGRErr gdal_rollback_transaction(void* cogr_ds):
    return OGRERR_NONE
